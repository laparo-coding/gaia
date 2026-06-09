#if canImport(SwiftUI)
  import SwiftUI

  public enum DashboardDesignTokens {
    public enum Colors {
      public static let background = Color(red: 0.95, green: 0.96, blue: 0.98)
      public static let surface = Color.white
      public static let surfaceMuted = Color(red: 0.98, green: 0.98, blue: 0.99)
      public static let textPrimary = Color(red: 0.11, green: 0.16, blue: 0.24)
      public static let textSecondary = Color(red: 0.40, green: 0.46, blue: 0.54)
      public static let healthy = Color(red: 0.15, green: 0.60, blue: 0.34)
      public static let degraded = Color(red: 0.96, green: 0.67, blue: 0.13)
      public static let unavailable = Color(red: 0.88, green: 0.24, blue: 0.22)
      public static let accent = Color(red: 0.10, green: 0.42, blue: 0.86)
    }

    public enum Spacing {
      public static let xs: CGFloat = 4
      public static let sm: CGFloat = 8
      public static let md: CGFloat = 12
      public static let lg: CGFloat = 16
      public static let xl: CGFloat = 20
      public static let xxl: CGFloat = 24
    }

    public enum CornerRadius {
      public static let card: CGFloat = 24
      public static let inner: CGFloat = 18
      public static let pill: CGFloat = 999
    }
  }
#endif
