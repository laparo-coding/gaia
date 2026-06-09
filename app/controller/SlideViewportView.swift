#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

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
      webView.loadHTMLString(htmlContent, baseURL: nil)
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
      webView.loadHTMLString(htmlContent, baseURL: nil)
    }
  }
#endif
#endif
