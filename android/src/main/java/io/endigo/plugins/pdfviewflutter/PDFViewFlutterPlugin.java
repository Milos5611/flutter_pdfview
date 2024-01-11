package io.endigo.plugins.pdfviewflutter;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

public class PDFViewFlutterPlugin implements FlutterPlugin {
    /**
     * Plugin registration.
     */
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        binding
                .getPlatformViewRegistry()
                .registerViewFactory("plugins.endigo.io/pdfview", new PDFViewFactory(binding.getBinaryMessenger()));
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }
}
