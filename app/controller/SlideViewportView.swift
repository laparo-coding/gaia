#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

extension SlideViewportView {
  /// Passt das Slide-HTML an den WebView-Viewport an.
  /// Die generierten Slides verwenden `width=1920` im viewport-meta-Tag,
  /// was WKWebView zwingt, 1920px logische Breite zu verwenden.
  /// Bei klealem Frame wird der Content winzig oder unsichtbar.
  /// Ersetzt durch `width=device-width` und fügt ein Scaling-Style hinzu.
  internal static func adaptedHTML(_ html: String) -> String {
    var adapted = html
    // Target only the viewport <meta> entry: replace width=1920 with width=device-width.
    let viewportPattern =
      #"<meta\b(?=[^>]*\bname\s*=\s*['\"]viewport['\"])[^>]*>"#
    if let range = adapted.range(of: viewportPattern, options: [.regularExpression, .caseInsensitive]) {
      let original = String(adapted[range])
      let replaced = original.replacingOccurrences(of: "width=1920", with: "width=device-width")
      adapted.replaceSubrange(range, with: replaced)
    }
    // Inject style only at the actual head close.
    let injectStyle = """
      <style>
        html, body { width: 100% !important; height: 100% !important; }
        body { transform-origin: center; }
      </style>
      """
    let headClosePattern = #"</head>"#
    if let range = adapted.range(of: headClosePattern, options: [.regularExpression, .caseInsensitive]) {
      adapted.replaceSubrange(range, with: "\(injectStyle)\(headClosePattern)")
    }
    return adapted
  }
}

#if canImport(UIKit)
  internal struct SlideViewportView: UIViewRepresentable {
    let htmlContent: String

    internal final class Coordinator {
      var lastHTML: String?
    }

    internal func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    internal func makeUIView(context _: Context) -> WKWebView {
      let webView = WKWebView()
      webView.isOpaque = false
      webView.backgroundColor = .clear
      return webView
    }

    internal func updateUIView(_ webView: WKWebView, context: Context) {
      guard context.coordinator.lastHTML != htmlContent else {
        return
      }

      context.coordinator.lastHTML = htmlContent
      webView.loadHTMLString(Self.adaptedHTML(htmlContent), baseURL: nil)
    }
  }
#elseif canImport(AppKit)
  internal struct SlideViewportView: NSViewRepresentable {
    let htmlContent: String

    internal final class Coordinator {
      var lastHTML: String?
    }

    internal func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    internal func makeNSView(context _: Context) -> WKWebView {
      let webView = WKWebView()
      webView.setValue(false, forKey: "drawsBackground")
      return webView
    }

    internal func updateNSView(_ webView: WKWebView, context: Context) {
      guard context.coordinator.lastHTML != htmlContent else {
        return
      }

      context.coordinator.lastHTML = htmlContent
      webView.loadHTMLString(Self.adaptedHTML(htmlContent), baseURL: nil)
    }
  }
#endif
#endif
