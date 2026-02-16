import { Controller } from "@hotwired/stimulus"

// Converts UTC <time> elements to the user's local timezone using Intl.DateTimeFormat.
//
// Usage:
//   <time datetime="2026-02-14T21:30:00Z"
//         data-controller="local-time"
//         data-local-time-format-value="short-date">
//     Feb 14, 2026
//   </time>
//
export default class extends Controller {
  static values = { format: { type: String, default: "short-date" } }

  connect() {
    const iso = this.element.getAttribute("datetime")
    if (!iso) return

    const date = new Date(iso)
    if (isNaN(date.getTime())) return

    this.element.textContent = this.formatDate(date)
  }

  formatDate(date) {
    const locale = navigator.language || "en-US"

    switch (this.formatValue) {
      case "short-date":
        return new Intl.DateTimeFormat(locale, {
          month: "short", day: "numeric", year: "numeric"
        }).format(date)

      case "long-date":
        return new Intl.DateTimeFormat(locale, {
          month: "long", day: "numeric", year: "numeric"
        }).format(date)

      case "month-day":
        return new Intl.DateTimeFormat(locale, {
          month: "short", day: "numeric"
        }).format(date)

      case "short-datetime":
        return new Intl.DateTimeFormat(locale, {
          month: "short", day: "numeric", year: "numeric",
          hour: "numeric", minute: "2-digit"
        }).format(date)

      case "long-datetime":
        return new Intl.DateTimeFormat(locale, {
          month: "long", day: "numeric", year: "numeric",
          hour: "numeric", minute: "2-digit", second: "2-digit"
        }).format(date)

      case "time-only":
        return new Intl.DateTimeFormat(locale, {
          hour: "numeric", minute: "2-digit", second: "2-digit"
        }).format(date)

      case "compact-datetime":
        return new Intl.DateTimeFormat(locale, {
          month: "short", day: "numeric",
          hour: "numeric", minute: "2-digit"
        }).format(date)

      case "month-year":
        return new Intl.DateTimeFormat(locale, {
          month: "short", year: "numeric"
        }).format(date)

      case "month-only":
        return new Intl.DateTimeFormat(locale, {
          month: "short"
        }).format(date)

      default:
        return new Intl.DateTimeFormat(locale, {
          month: "short", day: "numeric", year: "numeric"
        }).format(date)
    }
  }
}
