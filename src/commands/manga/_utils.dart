import 'dart:io';
import 'dart:typed_data';
import 'package:dl/dl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tenka/tenka.dart';
import 'package:utilx/utils.dart';
import '../../utils/others.dart';
import '../../utils/progress_bar.dart';

typedef GetPdfDestinationFn = String Function({
  required String mimeType,
});

typedef GetImageDestinationFn = String Function({
  required String mimeType,
  required int pageNumber,
});

class MangaDownloader {
  static const Downloader<RawDLProvider> downloader =
      Downloader<RawDLProvider>(provider: RawDLProvider());

  static Future<void> downloadAsImages({
    required final List<PageInfo> pages,
    required final MangaExtractor extractor,
    required final String leftSpace,
    required final GetImageDestinationFn getDestination,
  }) async {
    const ProgressBar bar = ProgressBar();

    final List<TwinTuple<List<int>, String>> data = await _download(
      pages: pages,
      extractor: extractor,
      leftSpace: leftSpace,
      bar: bar,
      onData: (final DLResponse res, final List<int> data) =>
          TwinTuple<List<int>, String>(
        data,
        getFileExtensionFromDLResponse(res)!,
      ),
    );

    int i = 1;
    for (final TwinTuple<List<int>, String> x in data) {
      final File file = File(
        getDestination(
          mimeType: x.last,
          pageNumber: i,
        ),
      );

      await FSUtils.ensureFile(file);
      await file.writeAsBytes(x.first);
      i++;
    }

    bar.end();
  }

  static Future<void> downloadAsPdf({
    required final List<PageInfo> pages,
    required final MangaExtractor extractor,
    required final String leftSpace,
    required final GetPdfDestinationFn getDestination,
  }) async {
    const ProgressBar bar = ProgressBar();

    final List<List<int>> data = await _download(
      pages: pages,
      extractor: extractor,
      leftSpace: leftSpace,
      bar: bar,
      onData: (final DLResponse res, final List<int> data) => data,
    );

    final pw.Document document = pw.Document();
    for (final List<int> x in data) {
      document.addPage(
        pw.Page(
          build: (final pw.Context context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Image(pw.MemoryImage(Uint8List.fromList(x))),
            ),
          ),
        ),
      );
    }

    final File file = File(getDestination(mimeType: 'pdf'));
    await FSUtils.ensureFile(file);
    await file.writeAsBytes(await document.save());

    bar.end();
  }

  static Future<List<T>> _download<T>({
    required final List<PageInfo> pages,
    required final MangaExtractor extractor,
    required final String leftSpace,
    required final ProgressBar bar,
    required final T Function(DLResponse, List<int>) onData,
  }) async {
    int current = 0;
    final int total = pages.length;
    void incrementBar() {
      current++;
      bar.set(
        (current / total) * 100,
        current: onlyIfAboveZero(current),
        total: onlyIfAboveZero(total),
        prefix: leftSpace,
      );
    }

    return Future.wait<T>(
      pages.asMap().keys.map((final int i) async {
        final PageInfo x = pages[i];
        final ImageDescriber image = await extractor.getPage(x.url, x.locale);
        final DLResponse res = await downloader.download(
          url: Uri.parse(image.url),
          headers: image.headers,
        );

        final List<int> data = await res.data.fold<List<int>>(
          <int>[],
          (final List<int> p, final List<int> x) => p..addAll(x),
        );

        incrementBar();

        return onData(res, data);
      }),
    );
  }
}