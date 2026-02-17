import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "slug"]

  generateSlug() {
    if (!this.hasSlugTarget) return
    // Only auto-generate if slug is empty or matches a previous auto-generation
    const slug = this.slugTarget
    if (slug.dataset.manuallyEdited === "true") return

    const name = this.nameTarget.value
    slug.value = name
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, "")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
  }

  slugEdited() {
    if (this.hasSlugTarget) {
      this.slugTarget.dataset.manuallyEdited = "true"
    }
  }
}
