import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.element.addEventListener("dragstart", this.dragStart.bind(this))
    this.element.addEventListener("dragover", this.dragOver.bind(this))
    this.element.addEventListener("drop", this.drop.bind(this))
    this.element.addEventListener("dragend", this.dragEnd.bind(this))
  }

  dragStart(event) {
    const row = event.target.closest("[data-sortable-id]")
    if (!row) return
    event.dataTransfer.setData("text/plain", row.dataset.sortableId)
    row.classList.add("opacity-50")
    this.draggedRow = row
  }

  dragOver(event) {
    event.preventDefault()
    const row = event.target.closest("[data-sortable-id]")
    if (!row || row === this.draggedRow) return
    row.classList.add("border-t-2", "border-primary")
  }

  drop(event) {
    event.preventDefault()
    const targetRow = event.target.closest("[data-sortable-id]")
    if (!targetRow || targetRow === this.draggedRow) return

    // Reorder DOM
    targetRow.parentNode.insertBefore(this.draggedRow, targetRow)

    // Collect new order
    const items = [...this.element.querySelectorAll("[data-sortable-id]")]
    const positions = items.map((item, index) => ({
      id: item.dataset.sortableId,
      position: index
    }))

    // Submit reorder
    if (this.hasUrlValue) {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ positions })
      })
    }

    // Clean up styles
    this.element.querySelectorAll("[data-sortable-id]").forEach(row => {
      row.classList.remove("border-t-2", "border-primary")
    })
  }

  dragEnd() {
    if (this.draggedRow) {
      this.draggedRow.classList.remove("opacity-50")
    }
    this.element.querySelectorAll("[data-sortable-id]").forEach(row => {
      row.classList.remove("border-t-2", "border-primary")
    })
  }
}
