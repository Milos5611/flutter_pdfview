package io.endigo.plugins.pdfviewflutter;

public class SearchResult {
  public final String text;
  public final int pageNumber;

  public SearchResult(int pageNumber, String text) {
    this.text = text;
    this.pageNumber = pageNumber;
  }
}
