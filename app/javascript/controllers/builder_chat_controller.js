import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messagesContainer", "messageInput", "sendButton", "typingIndicator", "panel", "subtitle", "agentSelect"]
  static values = {
    agentId: String,
    sendUrl: String,
    pollUrl: String,
    approveUrl: String,
    rejectUrl: String,
    clearUrl: String,
    sessionUrl: String,
    executionId: String,
    pollInterval: { type: Number, default: 2000 },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.pollTimer = null
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    // Resume polling if there's an active execution
    if (this.executionIdValue) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  togglePanel() {
    this.openValue = !this.openValue
    if (this.openValue) {
      this.panelTarget.classList.remove("translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
      this.scrollToBottom()
    } else {
      this.panelTarget.classList.remove("translate-x-0")
      this.panelTarget.classList.add("translate-x-full")
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage()
    }
  }

  async sendMessage() {
    const input = this.messageInputTarget
    const message = input.value.trim()
    if (!message) return

    // Disable input while sending
    input.value = ""
    this.sendButtonTarget.disabled = true
    input.disabled = true

    // Append user message bubble
    this.appendMessage("user", message)
    this.showTyping()

    try {
      const response = await fetch(this.sendUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          message: message,
          agent_id: this.agentIdValue
        })
      })

      const data = await response.json()
      if (data.error) {
        this.hideTyping()
        this.appendMessage("system", `Error: ${data.error}`)
      } else {
        this.executionIdValue = data.execution_id
        this.startPolling()
      }
    } catch (err) {
      this.hideTyping()
      this.appendMessage("system", "Failed to send message. Please try again.")
    } finally {
      this.sendButtonTarget.disabled = false
      input.disabled = false
      input.focus()
    }
  }

  startPolling() {
    this.stopPolling()
    this.pollTimer = setInterval(() => this.pollExecution(), this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async pollExecution() {
    if (!this.executionIdValue) {
      this.stopPolling()
      return
    }

    try {
      const url = new URL(this.pollUrlValue, window.location.origin)
      url.searchParams.set("execution_id", this.executionIdValue)
      if (this.agentIdValue) url.searchParams.set("agent_id", this.agentIdValue)

      const response = await fetch(url, {
        headers: { "X-CSRF-Token": this.csrfToken }
      })
      const data = await response.json()

      if (data.status === "awaiting_approval") {
        this.hideTyping()
        this.showApprovalCard(data.pending_step)
        this.stopPolling()
      } else if (data.status === "completed") {
        this.hideTyping()
        this.stopPolling()
        this.executionIdValue = ""
        if (data.response_text) {
          this.appendMessage("assistant", data.response_text)
        }
        if (data.agent_modified) {
          this.dispatchAgentUpdated()
        }
      } else if (data.status === "failed") {
        this.hideTyping()
        this.stopPolling()
        this.executionIdValue = ""
        this.appendMessage("system", data.error_message || "Execution failed.")
      }
      // else still running, keep polling
    } catch (err) {
      // Network error, keep polling
      console.warn("Poll error:", err)
    }
  }

  showApprovalCard(step) {
    if (!step) return

    const card = document.createElement("div")
    card.className = "chat chat-start mb-2"
    card.innerHTML = `
      <div class="chat-bubble bg-warning/10 border border-warning/30 text-base-content w-full max-w-none">
        <div class="flex items-center gap-2 mb-2">
          <span class="badge badge-warning badge-sm">Approval Needed</span>
          <span class="font-semibold text-sm">${this.escapeHtml(step.tool_name || "Action")}</span>
        </div>
        <div class="text-sm opacity-80 mb-3">${this.escapeHtml(step.description || "The agent wants to perform an action that requires your approval.")}</div>
        ${step.details ? `
          <details class="mb-3">
            <summary class="text-xs cursor-pointer opacity-60">View details</summary>
            <pre class="text-xs mt-1 p-2 bg-base-200 rounded overflow-x-auto">${this.escapeHtml(JSON.stringify(step.details, null, 2))}</pre>
          </details>
        ` : ""}
        <div class="flex gap-2">
          <button class="btn btn-success btn-sm" data-action="click->builder-chat#approveStep" data-step-number="${step.step_number}" data-execution-id="${step.execution_id}">
            <i class="fas fa-check mr-1"></i> Approve
          </button>
          <button class="btn btn-error btn-sm btn-outline" data-action="click->builder-chat#rejectStep" data-step-number="${step.step_number}" data-execution-id="${step.execution_id}">
            <i class="fas fa-times mr-1"></i> Reject
          </button>
        </div>
      </div>
    `
    this.messagesContainerTarget.appendChild(card)
    this.scrollToBottom()
  }

  async approveStep(event) {
    const btn = event.currentTarget
    const stepNumber = btn.dataset.stepNumber
    const executionId = btn.dataset.executionId

    // Disable buttons
    const card = btn.closest(".chat")
    card.querySelectorAll("button").forEach(b => b.disabled = true)

    try {
      const response = await fetch(this.approveUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          execution_id: executionId,
          step_number: parseInt(stepNumber),
          agent_id: this.agentIdValue
        })
      })

      const data = await response.json()
      if (data.status === "ok") {
        // Replace card with approval confirmation
        card.innerHTML = `
          <div class="chat-bubble bg-success/10 border border-success/30 text-base-content">
            <span class="badge badge-success badge-sm mr-1">Approved</span>
            Step approved. Continuing...
          </div>
        `
        this.executionIdValue = executionId
        this.showTyping()
        this.startPolling()
      } else {
        this.appendMessage("system", data.error || "Failed to approve step.")
      }
    } catch (err) {
      this.appendMessage("system", "Failed to approve step. Please try again.")
    }
  }

  async rejectStep(event) {
    const btn = event.currentTarget
    const stepNumber = btn.dataset.stepNumber
    const executionId = btn.dataset.executionId

    const card = btn.closest(".chat")
    card.querySelectorAll("button").forEach(b => b.disabled = true)

    try {
      const response = await fetch(this.rejectUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          execution_id: executionId,
          step_number: parseInt(stepNumber),
          agent_id: this.agentIdValue
        })
      })

      const data = await response.json()
      if (data.status === "ok") {
        card.innerHTML = `
          <div class="chat-bubble bg-error/10 border border-error/30 text-base-content">
            <span class="badge badge-error badge-sm mr-1">Rejected</span>
            Step rejected.
          </div>
        `
        this.executionIdValue = executionId
        this.showTyping()
        this.startPolling()
      } else {
        this.appendMessage("system", data.error || "Failed to reject step.")
      }
    } catch (err) {
      this.appendMessage("system", "Failed to reject step. Please try again.")
    }
  }

  async clearChat() {
    if (!confirm("Clear chat history and start fresh?")) return

    try {
      const response = await fetch(this.clearUrlValue, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ agent_id: this.agentIdValue })
      })

      const data = await response.json()
      if (data.status === "ok") {
        // Clear messages and show welcome
        this.messagesContainerTarget.innerHTML = ""
        this.appendMessage("system", data.welcome_message || "Chat cleared. How can I help you configure this agent?")
        this.executionIdValue = ""
        this.stopPolling()
      }
    } catch (err) {
      this.appendMessage("system", "Failed to clear chat.")
    }
  }

  async switchAgent(event) {
    const newAgentId = event.target.value
    this.agentIdValue = newAgentId
    this.stopPolling()
    this.executionIdValue = ""

    try {
      const url = new URL(this.sessionUrlValue, window.location.origin)
      if (newAgentId) url.searchParams.set("agent_id", newAgentId)

      const response = await fetch(url, {
        headers: { "X-CSRF-Token": this.csrfToken }
      })
      const data = await response.json()

      // Update messages area
      this.messagesContainerTarget.innerHTML = data.messages_html

      // Update subtitle
      if (this.hasSubtitleTarget) {
        this.subtitleTarget.textContent = data.agent_id
          ? `Configuring: ${data.agent_name}`
          : "Create a new agent"
      }

      // Resume polling if there's an active execution
      if (data.execution_id) {
        this.executionIdValue = String(data.execution_id)
        this.startPolling()
      }

      this.scrollToBottom()
    } catch (err) {
      this.appendMessage("system", "Failed to switch agent. Please try again.")
    }
  }

  // UI Helpers

  appendMessage(role, content) {
    const div = document.createElement("div")
    const alignment = role === "user" ? "chat-end" : "chat-start"
    const bubbleClass = role === "user" ? "chat-bubble-primary" : role === "system" ? "chat-bubble bg-base-200 text-base-content/60" : "chat-bubble"

    div.className = `chat ${alignment} mb-1`
    div.innerHTML = `<div class="chat-bubble ${bubbleClass} text-sm">${this.formatContent(content)}</div>`

    this.messagesContainerTarget.appendChild(div)
    this.scrollToBottom()
  }

  showTyping() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove("hidden")
    }
    this.scrollToBottom()
  }

  hideTyping() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.add("hidden")
    }
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
    })
  }

  formatContent(text) {
    if (!text) return ""
    // Basic markdown: bold, italic, code blocks, inline code, line breaks
    let html = this.escapeHtml(text)
    html = html.replace(/```([\s\S]*?)```/g, '<pre class="bg-base-200 p-2 rounded text-xs my-1 overflow-x-auto">$1</pre>')
    html = html.replace(/`([^`]+)`/g, '<code class="bg-base-200 px-1 rounded text-xs">$1</code>')
    html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    html = html.replace(/\*(.+?)\*/g, "<em>$1</em>")
    html = html.replace(/\n/g, "<br>")
    return html
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  dispatchAgentUpdated() {
    document.dispatchEvent(new CustomEvent("builder-chat:agentUpdated"))
  }
}
