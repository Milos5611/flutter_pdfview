package io.endigo.plugins.pdfviewflutter;

import android.content.Context;
import android.graphics.pdf.PdfDocument;
import android.os.Build;

import com.github.barteksc.pdfviewer.PDFView;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.text.PDFTextStripper;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

public class PDFSearch {
  PdfDocument pdfDocument;
  Context context;
  MethodChannel methodChannel;

  public PDFSearch(Context context, PdfDocument pdfDocument, MethodChannel methodChannel) {
    this.context = context;
    this.pdfDocument = pdfDocument;
    this.methodChannel = methodChannel;
  }

  public static void main(String[] args) {
    String filePath = "path/to/your/document.pdf"; // Replace with the path to your PDF file
    String searchText = "search text"; // Replace with the text you are searching for

    Map<String, Integer> searchResults = searchTextInPdf(filePath, searchText);
    if (searchResults.isEmpty()) {
      System.out.println("Text not found");
    } else {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        searchResults.forEach((text, pageNumber) -> {
          System.out.println("Text '" + text + "' found on page " + pageNumber);
        });
      }
    }
  }

  public static Map<String, Integer> searchTextInPdf(String filePath, String searchText) {
    Map<String, Integer> results = new HashMap<>();
    File file = new File(filePath);

    try (PDDocument document = PDDocument.load(file)) {
      PDFTextStripper stripper = new PDFTextStripper();
      for (int page = 1; page <= document.getNumberOfPages(); ++page) {
        stripper.setStartPage(page);
        stripper.setEndPage(page);
        String text = stripper.getText(document);
        if (text.contains(searchText)) {
          results.put(searchText, page);
        }
      }
    } catch (IOException e) {
      e.printStackTrace();
    }
    return results;
  }
}
