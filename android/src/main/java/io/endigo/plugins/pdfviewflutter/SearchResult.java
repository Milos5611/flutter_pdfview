package io.endigo.plugins.pdfviewflutter;

public class SearchResult {
  public final String text;
  public final int pageNumber;

  public SearchResult(String text, int pageNumber) {
    this.text = text;
    this.pageNumber = pageNumber;
  }
}
