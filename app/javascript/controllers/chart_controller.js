import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    type: { type: String, default: "bar" },
    labels: Array,
    data: Array,
    label: { type: String, default: "Value" }
  }

  connect() {
    if (typeof Chart === "undefined") {
      console.warn("Chart.js not loaded")
      return
    }

    const ctx = this.canvasTarget.getContext("2d")
    const colors = [
      "#4C3F6D", "#489DF9", "#36D399", "#FBBD23", "#F87272",
      "#A78BFA", "#34D399", "#F472B6", "#60A5FA", "#FBBF24"
    ]

    const config = {
      type: this.typeValue,
      data: {
        labels: this.labelsValue,
        datasets: [{
          label: this.labelValue,
          data: this.dataValue,
          backgroundColor: colors.slice(0, this.dataValue.length),
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            display: ["pie", "doughnut"].includes(this.typeValue)
          }
        }
      }
    }

    new Chart(ctx, config)
  }
}
