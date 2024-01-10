package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.util.Log;
import android.view.View;
import android.net.Uri;
import android.widget.EditText;
import android.widget.ImageButton;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.platform.PlatformView;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.PDFView.Configurator;
import com.github.barteksc.pdfviewer.listener.*;
import com.github.barteksc.pdfviewer.util.FitPolicy;

import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.itextpdf.text.pdf.PdfDocument;
import com.itextpdf.text.pdf.PdfReader;
import com.itextpdf.text.pdf.parser.PdfTextExtractor;

public class FlutterPDFView implements PlatformView, MethodCallHandler {
  private final PDFView pdfView;
  private final MethodChannel methodChannel;
  private final LinkHandler linkHandler;
  private String filePath;
  private Context context;

  String extractedText="";
  ImageButton btn_search;

  Integer j;
  List<Integer> aparitii= new ArrayList<>();
  EditText searchPDF;
  List<Integer> listapagini= new ArrayList<>();

  @SuppressWarnings("unchecked")
  FlutterPDFView(Context context, BinaryMessenger messenger, int id, Map<String, Object> params) {
    pdfView = new PDFView(context, null);
    this.context = context;
    final boolean preventLinkNavigation = getBoolean(params, "preventLinkNavigation");

    methodChannel = new MethodChannel(messenger, "plugins.endigo.io/pdfview_" + id);
    methodChannel.setMethodCallHandler(this);

    linkHandler = new PDFLinkHandler(context, pdfView, methodChannel, preventLinkNavigation);

    Configurator config = null;
    if (params.get("filePath") != null) {
      String filePath = (String) params.get("filePath");
      this.filePath = filePath;
      config = pdfView.fromUri(getURI(filePath));
    } else if (params.get("pdfData") != null) {
      byte[] data = (byte[]) params.get("pdfData");
      config = pdfView.fromBytes(data);
    }

    if (config != null) {
      config
        .enableSwipe(getBoolean(params, "enableSwipe"))
        .swipeHorizontal(getBoolean(params, "swipeHorizontal"))
        .password(getString(params, "password"))
        .nightMode(getBoolean(params, "nightMode"))
        .autoSpacing(getBoolean(params, "autoSpacing"))
        .pageFling(getBoolean(params, "pageFling"))
        .pageSnap(getBoolean(params, "pageSnap"))
        .pageFitPolicy(getFitPolicy(params))
        .enableAnnotationRendering(true)
        .linkHandler(linkHandler)
        .enableAntialiasing(false)
        // .fitEachPage(getBoolean(params,"fitEachPage"))
        .onPageChange(new OnPageChangeListener() {
          @Override
          public void onPageChanged(int page, int total) {
            Map<String, Object> args = new HashMap<>();
            args.put("page", page);
            args.put("total", total);
            methodChannel.invokeMethod("onPageChanged", args);
          }
        }).onError(new OnErrorListener() {
          @Override
          public void onError(Throwable t) {
            Map<String, Object> args = new HashMap<>();
            args.put("error", t.toString());
            methodChannel.invokeMethod("onError", args);
          }
        }).onPageError(new OnPageErrorListener() {
          @Override
          public void onPageError(int page, Throwable t) {
            Map<String, Object> args = new HashMap<>();
            args.put("page", page);
            args.put("error", t.toString());
            methodChannel.invokeMethod("onPageError", args);
          }
        }).onRender(new OnRenderListener() {
          @Override
          public void onInitiallyRendered(int pages) {
            Map<String, Object> args = new HashMap<>();
            args.put("pages", pages);
            methodChannel.invokeMethod("onRender", args);
          }
        }).enableDoubletap(true).defaultPage(getInt(params, "defaultPage")).load();
    }
  }

  @Override
  public View getView() {
    return pdfView;
  }

  @Override
  public void onMethodCall(MethodCall methodCall, Result result) {
    switch (methodCall.method) {
      case "pageCount":
        getPageCount(result);
        break;
      case "currentPage":
        getCurrentPage(result);
        break;
      case "setPage":
        setPage(methodCall, result);
        break;
      case "updateSettings":
        updateSettings(methodCall, result);
        break;
      case "searchPdfTextForText":
        try {
          searchTextInPdf(methodCall, result);
        } catch (IOException e) {
          throw new RuntimeException(e);
        } catch (InterruptedException e) {
          throw new RuntimeException(e);
        } catch (ExecutionException e) {
          throw new RuntimeException(e);
        }
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  List<SearchResult> searchTextInPdf(MethodCall call, Result result) throws IOException, InterruptedException, ExecutionException {
    String searchText = call.argument("searchText");
    final PdfReader reader = new PdfReader(filePath);
    int numPages = reader.getNumberOfPages();
    int numThreads = Runtime.getRuntime().availableProcessors(); // Number of available cores
    ExecutorService executor = Executors.newFixedThreadPool(numThreads);

    List<Future<List<SearchResult>>> futures = new ArrayList<>();

    // Submit tasks to thread pool
    for (int i = 1; i <= numPages; i++) {
      final int pageNumber = i;
      futures.add(executor.submit(new Callable<List<SearchResult>>() {
        @Override
        public List<SearchResult> call() throws Exception {
          List<SearchResult> results = new ArrayList<>();
          String pageContent = PdfTextExtractor.getTextFromPage(reader, pageNumber);
          if (pageContent.contains(searchText)) {
            results.add(new SearchResult(searchText, pageNumber));
          }
          return results;
        }
      }));
    }

    // Wait for all tasks to complete and gather results
    List<SearchResult> searchResults = new ArrayList<>();
    for (Future<List<SearchResult>> future : futures) {
      searchResults.addAll(future.get());
    }

    // Shutdown the executor service
    executor.shutdown();

    reader.close();
    return searchResults;
  }

  void getPageCount(Result result) {
    result.success(pdfView.getPageCount());
  }

  void getCurrentPage(Result result) {
    result.success(pdfView.getCurrentPage());
  }

  void setPage(MethodCall call, Result result) {
    if (call.argument("page") != null) {
      int page = (int) call.argument("page");
      pdfView.jumpTo(page);
    }

    result.success(true);
  }

  @SuppressWarnings("unchecked")
  private void updateSettings(MethodCall methodCall, Result result) {
    applySettings((Map<String, Object>) methodCall.arguments);
    result.success(null);
  }

  private void applySettings(Map<String, Object> settings) {
    for (String key : settings.keySet()) {
      switch (key) {
        case "enableSwipe":
          pdfView.setSwipeEnabled(getBoolean(settings, key));
          break;
        case "nightMode":
          pdfView.setNightMode(getBoolean(settings, key));
          break;
        case "pageFling":
          pdfView.setPageFling(getBoolean(settings, key));
          break;
        case "pageSnap":
          pdfView.setPageSnap(getBoolean(settings, key));
          break;
        case "preventLinkNavigation":
          final PDFLinkHandler plh = (PDFLinkHandler) this.linkHandler;
          plh.setPreventLinkNavigation(getBoolean(settings, key));
          break;
        default:
          throw new IllegalArgumentException("Unknown PDFView setting: " + key);
      }
    }
  }

  @Override
  public void dispose() {
    methodChannel.setMethodCallHandler(null);
  }

  boolean getBoolean(Map<String, Object> params, String key) {
    return params.containsKey(key) ? (boolean) params.get(key) : false;
  }

  String getString(Map<String, Object> params, String key) {
    return params.containsKey(key) ? (String) params.get(key) : "";
  }

  int getInt(Map<String, Object> params, String key) {
    return params.containsKey(key) ? (int) params.get(key) : 0;
  }

  FitPolicy getFitPolicy(Map<String, Object> params) {
    String fitPolicy = getString(params, "fitPolicy");
    switch (fitPolicy) {
      case "FitPolicy.WIDTH":
        return FitPolicy.WIDTH;
      case "FitPolicy.HEIGHT":
        return FitPolicy.HEIGHT;
      case "FitPolicy.BOTH":
      default:
        return FitPolicy.BOTH;
    }
  }

  private Uri getURI(final String uri) {
    Uri parsed = Uri.parse(uri);

    if (parsed.getScheme() == null || parsed.getScheme().isEmpty()) {
      return Uri.fromFile(new File(uri));
    }
    return parsed;
  }

}

