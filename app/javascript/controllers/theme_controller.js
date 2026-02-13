import { Controller } from "@hotwired/stimulus"

const LIGHT = "corporate"
const DARK = "business"
const STORAGE_KEY = "theme"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    const stored = localStorage.getItem(STORAGE_KEY)
    const theme = stored || (window.matchMedia("(prefers-color-scheme: dark)").matches ? DARK : LIGHT)
    this.applyTheme(theme)
  }

  toggle() {
    const current = document.documentElement.dataset.theme
    const next = current === DARK ? LIGHT : DARK
    localStorage.setItem(STORAGE_KEY, next)
    this.applyTheme(next)
  }

  applyTheme(theme) {
    document.documentElement.dataset.theme = theme
    if (this.hasIconTarget) {
      this.iconTarget.className = theme === DARK ? "fas fa-sun w-5 text-center" : "fas fa-moon w-5 text-center"
    }
  }
}
