package io.endigo.plugins.pdfviewflutter;

public class SearchResult {
  public final String text;
  public final int page;

  public SearchResult(int page, String text) {
    this.text = text;
    this.page = page;
  }
}
