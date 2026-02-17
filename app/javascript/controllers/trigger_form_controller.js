import { Controller } from "@hotwired/stimulus"

const HELP_TEXT = {
  event: "Events fire when internal processes raise named events. Stripe webhook events (e.g. stripe.invoice.paid) and agent execution events are available. Select from the dropdown or type a custom event name.",
  schedule: "Runs on a time-based schedule using cron expressions. The agent executes automatically at the specified interval. No external data is passed to the agent.",
  data: "Polls a tool's API on a schedule and evaluates conditions against the output. The agent only fires when conditions are met. Set the check interval and conditions below.",
  webhook: "Generates a unique URL after creation. External services POST JSON to this URL to fire the trigger. The JSON payload is passed as input data to the agent.",
  dependency: "Fires when another agent completes an execution. Use conditions to filter on the upstream agent's output (e.g. status, output fields).",
  manual: "Fire manually using the play button in the triggers list. Useful for testing or on-demand agent execution."
}

export default class extends Controller {
  static targets = [
    "typeSelect",
    "scheduleSection", "dataSection", "dependencySection",
    "webhookSection", "eventSection",
    "conditionField", "conditionRows", "matchMode",
    "schedulePreset", "scheduleCron",
    "helpPanel", "helpContent",
    "eventNameInput", "toolSelect"
  ]

  static values = {
    schemaUrl: { type: String, default: "/api/trigger_schemas" }
  }

  connect() {
    this.cachedFields = []
    this.toggleSections()
  }

  toggleSections() {
    const type = this.typeSelectTarget.value

    if (this.hasScheduleSectionTarget) this.scheduleSectionTarget.classList.toggle("hidden", type !== "schedule")
    if (this.hasDataSectionTarget) this.dataSectionTarget.classList.toggle("hidden", type !== "data")
    if (this.hasDependencySectionTarget) this.dependencySectionTarget.classList.toggle("hidden", type !== "dependency")
    if (this.hasWebhookSectionTarget) this.webhookSectionTarget.classList.toggle("hidden", type !== "webhook")
    if (this.hasEventSectionTarget) this.eventSectionTarget.classList.toggle("hidden", type !== "event")

    this.updateHelpPanel(type)
    this.fetchSchema()
  }

  updateHelpPanel(type) {
    if (!this.hasHelpPanelTarget || !this.hasHelpContentTarget) return

    const text = HELP_TEXT[type]
    if (text) {
      this.helpContentTarget.textContent = text
      this.helpPanelTarget.classList.remove("hidden")
    } else {
      this.helpPanelTarget.classList.add("hidden")
    }
  }

  schedulePresetChanged() {
    if (!this.hasSchedulePresetTarget || !this.hasScheduleCronTarget) return
    const preset = this.schedulePresetTarget.value
    if (preset === "custom") {
      this.scheduleCronTarget.classList.remove("hidden")
    } else {
      this.scheduleCronTarget.classList.add("hidden")
    }
  }

  onEventChanged() {
    this.fetchSchema()
  }

  onToolChanged() {
    this.fetchSchema()
  }

  async fetchSchema() {
    const type = this.typeSelectTarget.value
    let url = null

    if (type === "event" && this.hasEventNameInputTarget && this.eventNameInputTarget.value) {
      url = `${this.schemaUrlValue}?context=event&event_name=${encodeURIComponent(this.eventNameInputTarget.value)}`
    } else if (type === "data" && this.hasToolSelectTarget && this.toolSelectTarget.value) {
      url = `${this.schemaUrlValue}?context=data&tool_definition_id=${this.toolSelectTarget.value}`
    } else if (type === "webhook") {
      url = `${this.schemaUrlValue}?context=webhook`
    } else if (type === "dependency") {
      url = `${this.schemaUrlValue}?context=dependency`
    }

    if (!url) {
      this.cachedFields = []
      return
    }

    try {
      const response = await fetch(url)
      if (response.ok) {
        const data = await response.json()
        this.cachedFields = data.fields || []
      } else {
        this.cachedFields = []
      }
    } catch {
      this.cachedFields = []
    }
  }

  addConditionRow() {
    if (!this.hasConditionRowsTarget) return

    const row = document.createElement("div")
    row.classList.add("flex", "gap-2", "items-center", "condition-row")

    // Build field input: select with known fields + custom option, or plain text
    let fieldHtml
    if (this.cachedFields.length > 0) {
      const options = this.cachedFields.map(f => {
        const label = f.description ? `${f.path} — ${f.description}` : f.path
        return `<option value="${f.path}">${label}</option>`
      }).join("")
      fieldHtml = `
        <select class="select select-bordered select-sm flex-1 condition-field-select" data-action="change->trigger-form#onFieldSelectChange">
          ${options}
          <option value="__custom__">Custom...</option>
        </select>
        <input type="text" placeholder="field.path" class="input input-bordered input-sm flex-1 condition-field-input hidden">
      `
    } else {
      fieldHtml = `<input type="text" placeholder="field.path" class="input input-bordered input-sm flex-1 condition-field-input">`
    }

    row.innerHTML = `
      ${fieldHtml}
      <select class="select select-bordered select-sm condition-operator">
        <option value="equals">equals</option>
        <option value="not_equals">not equals</option>
        <option value="greater_than">greater than</option>
        <option value="less_than">less than</option>
        <option value="greater_than_or_equal">>=</option>
        <option value="less_than_or_equal"><=</option>
        <option value="contains">contains</option>
        <option value="not_contains">not contains</option>
        <option value="starts_with">starts with</option>
        <option value="ends_with">ends with</option>
        <option value="exists">exists</option>
        <option value="not_exists">not exists</option>
        <option value="in">in</option>
        <option value="not_in">not in</option>
        <option value="matches">matches (regex)</option>
      </select>
      <input type="text" placeholder="value" class="input input-bordered input-sm flex-1 condition-value-input">
      <button type="button" class="btn btn-ghost btn-sm text-error" data-action="trigger-form#removeConditionRow">
        <i class="fas fa-times"></i>
      </button>
    `
    this.conditionRowsTarget.appendChild(row)
    this.serializeCondition()
  }

  onFieldSelectChange(event) {
    const select = event.target
    const row = select.closest(".condition-row")
    const textInput = row.querySelector(".condition-field-input")

    if (select.value === "__custom__") {
      textInput.classList.remove("hidden")
      textInput.focus()
    } else {
      textInput.classList.add("hidden")
      textInput.value = ""
    }
    this.serializeCondition()
  }

  removeConditionRow(event) {
    event.target.closest(".condition-row").remove()
    this.serializeCondition()
  }

  serializeCondition() {
    if (!this.hasConditionFieldTarget || !this.hasConditionRowsTarget) return

    const rows = this.conditionRowsTarget.querySelectorAll(".condition-row")
    const rules = []

    rows.forEach(row => {
      const fieldSelect = row.querySelector(".condition-field-select")
      const fieldInput = row.querySelector(".condition-field-input")
      const operator = row.querySelector(".condition-operator")?.value
      const value = row.querySelector(".condition-value-input")?.value

      let field
      if (fieldSelect && fieldSelect.value !== "__custom__") {
        field = fieldSelect.value
      } else {
        field = fieldInput?.value
      }

      if (field && operator) {
        const rule = { field, operator }
        if (!["exists", "not_exists"].includes(operator)) {
          const numVal = Number(value)
          rule.value = isNaN(numVal) || value === "" ? value : numVal
        }
        rules.push(rule)
      }
    })

    const matchMode = this.hasMatchModeTarget ? this.matchModeTarget.value : "all"

    if (rules.length > 0) {
      this.conditionFieldTarget.value = JSON.stringify({ match: matchMode, rules })
    } else {
      this.conditionFieldTarget.value = ""
    }
  }
}
