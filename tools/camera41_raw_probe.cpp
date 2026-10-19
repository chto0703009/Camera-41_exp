#include <libraw/libraw.h>

#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

namespace {
const char *probeArchitecture() {
#if defined(__aarch64__) || defined(__arm64__)
  return "arm64";
#elif defined(__x86_64__)
  return "x86_64";
#else
  return "unknown";
#endif
}

std::string escaped(const char *value) {
  std::ostringstream out;
  for (const unsigned char ch : std::string(value ? value : "")) {
    switch (ch) {
    case '\\': out << "\\\\"; break;
    case '"': out << "\\\""; break;
    case '\n': out << "\\n"; break;
    case '\r': out << "\\r"; break;
    case '\t': out << "\\t"; break;
    default:
      if (ch < 0x20) {
        out << "\\u" << std::hex << std::setw(4) << std::setfill('0')
            << static_cast<int>(ch) << std::dec;
      } else {
        out << ch;
      }
    }
  }
  return out.str();
}

std::string cfa2x2(LibRaw &raw) {
  const auto &sizes = raw.imgdata.sizes;
  const char *desc = raw.imgdata.idata.cdesc;
  std::string result;
  for (int row = 0; row < 2; ++row) {
    for (int column = 0; column < 2; ++column) {
      const int color = raw.COLOR(sizes.top_margin + row,
                                  sizes.left_margin + column);
      result += (color >= 0 && color < 4 && desc[color]) ? desc[color] : '?';
    }
  }
  return result;
}

int fail(const std::string &stage, int code) {
  std::cerr << stage << ": " << libraw_strerror(code) << '\n';
  return code == 0 ? 1 : code;
}
} // namespace

int main(int argc, char **argv) {
  if (argc == 2 && std::string(argv[1]) == "--build-info") {
    std::cout << "{\"Schema\":\"camera41.raw-probe-build-info.v0.2\","
              << "\"ProbeArchitecture\":\"" << probeArchitecture() << "\","
              << "\"LibRawVersion\":\"" << LibRaw::version() << "\"}\n";
    return 0;
  }
  if (argc != 4) {
    std::cerr << "Usage: camera41_raw_probe input.raw metadata.json mosaic.raw16le\n";
    return 2;
  }

  LibRaw raw;
  int code = raw.open_file(argv[1]);
  if (code != LIBRAW_SUCCESS) return fail("open_file", code);
  code = raw.unpack();
  if (code != LIBRAW_SUCCESS) return fail("unpack", code);
  if (!raw.imgdata.rawdata.raw_image) {
    std::cerr << "unpack: RAW file did not produce a Bayer mosaic\n";
    return 3;
  }

  const auto &sizes = raw.imgdata.sizes;
  const auto &identity = raw.imgdata.idata;
  const auto &color = raw.imgdata.color;
  const auto &other = raw.imgdata.other;
  const auto &shooting = raw.imgdata.shootinginfo;
  const auto &lens = raw.imgdata.lens;

  std::ofstream binary(argv[3], std::ios::binary | std::ios::trunc);
  if (!binary) {
    std::cerr << "Cannot create mosaic output: " << argv[3] << '\n';
    return 4;
  }
  const std::size_t sampleCount =
      static_cast<std::size_t>(sizes.raw_width) * sizes.raw_height;
  binary.write(reinterpret_cast<const char *>(raw.imgdata.rawdata.raw_image),
               static_cast<std::streamsize>(sampleCount * sizeof(std::uint16_t)));
  if (!binary) {
    std::cerr << "Cannot write complete mosaic output\n";
    return 5;
  }

  std::ofstream metadata(argv[2], std::ios::trunc);
  if (!metadata) {
    std::cerr << "Cannot create metadata output: " << argv[2] << '\n';
    return 6;
  }
  metadata << std::setprecision(12)
           << "{\n"
           << "  \"schema\": \"camera41.libraw-probe.v0.2\",\n"
           << "  \"libraw_version\": \"" << LibRaw::version() << "\",\n"
           << "  \"probe_architecture\": \"" << probeArchitecture() << "\",\n"
           << "  \"make\": \"" << escaped(identity.make) << "\",\n"
           << "  \"model\": \"" << escaped(identity.model) << "\",\n"
           << "  \"body_serial\": \"" << escaped(shooting.BodySerial) << "\",\n"
           << "  \"internal_body_serial\": \""
           << escaped(shooting.InternalBodySerial) << "\",\n"
           << "  \"lens_make\": \"" << escaped(lens.LensMake) << "\",\n"
           << "  \"lens_model\": \"" << escaped(lens.Lens) << "\",\n"
           << "  \"lens_serial\": \"" << escaped(lens.LensSerial) << "\",\n"
           << "  \"internal_lens_serial\": \""
           << escaped(lens.InternalLensSerial) << "\",\n"
           << "  \"raw_count\": " << identity.raw_count << ",\n"
           << "  \"raw_width\": " << sizes.raw_width << ",\n"
           << "  \"raw_height\": " << sizes.raw_height << ",\n"
           << "  \"visible_width\": " << sizes.width << ",\n"
           << "  \"visible_height\": " << sizes.height << ",\n"
           << "  \"left_margin\": " << sizes.left_margin << ",\n"
           << "  \"top_margin\": " << sizes.top_margin << ",\n"
           << "  \"raw_pitch_bytes\": " << sizes.raw_pitch << ",\n"
           << "  \"colors\": " << identity.colors << ",\n"
           << "  \"cfa_visible_2x2\": \"" << cfa2x2(raw) << "\",\n"
           << "  \"black_level\": " << color.black << ",\n"
           << "  \"black_level_channels\": ["
           << color.black + color.cblack[0] << ", "
           << color.black + color.cblack[1] << ", "
           << color.black + color.cblack[2] << ", "
           << color.black + color.cblack[3] << "],\n"
           << "  \"white_level\": " << color.maximum << ",\n"
           << "  \"data_maximum\": " << color.data_maximum << ",\n"
           << "  \"linearity_limits\": [" << color.linear_max[0] << ", "
           << color.linear_max[1] << ", " << color.linear_max[2] << ", "
           << color.linear_max[3] << "],\n"
           << "  \"iso\": " << other.iso_speed << ",\n"
           << "  \"shutter_seconds\": " << other.shutter << ",\n"
           << "  \"aperture\": " << other.aperture << ",\n"
           << "  \"focal_length_mm\": " << other.focal_len << ",\n"
           << "  \"timestamp_unix\": " << other.timestamp << ",\n"
           << "  \"sample_type\": \"uint16_le\",\n"
           << "  \"sample_count\": " << sampleCount << "\n"
           << "}\n";
  return metadata ? 0 : 7;
}
