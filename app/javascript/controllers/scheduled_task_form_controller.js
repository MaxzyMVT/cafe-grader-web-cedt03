import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    actions: Object,
    configs: Object,
    serverNowMs: Number
  }

  static targets = [
    "actionSelect",
    "actionDescription",
    "targetSection",
    "targetGroup",
    "systemModeSection",
    "configValueSection",
    "configSelect",
    "configInfo",
    "configCurrentValue",
    "configDescription",
    "configBooleanWrapper",
    "configTextWrapper",
    "configBooleanInput",
    "configTextInput",
    "scheduledAtInput",
    "serverClock"
  ]

  connect() {
    this._clientOffsetMs = this.hasServerNowMsValue ? (this.serverNowMsValue - Date.now()) : 0
    if (this.hasConfigSelectTarget && window.jQuery) {
      window.jQuery(this.configSelectTarget).on("select2:select.scheduledTask change.scheduledTask", () => {
        this.updateConfigUI()
      })
    }
    this.updateActionUI()
    this.updateConfigUI()
    this._startClock()
  }

  disconnect() {
    if (this.hasConfigSelectTarget && window.jQuery) {
      window.jQuery(this.configSelectTarget).off(".scheduledTask")
    }
    if (this._clockTimer) {
      clearInterval(this._clockTimer)
      this._clockTimer = null
    }
  }

  updateActionUI() {
    if (!this.hasActionSelectTarget) return
    const actionKey = this.actionSelectTarget.value
    const defn = this.actionsValue[actionKey] || {}

    if (this.hasActionDescriptionTarget) {
      this.actionDescriptionTarget.textContent = defn.description || ""
    }

    const targetType = defn.target_type || ""
    if (this.hasTargetSectionTarget) {
      this.targetSectionTarget.classList.toggle("d-none", !targetType)
    }

    this.targetGroupTargets.forEach((el) => {
      const isMatch = el.dataset.targetType === targetType
      el.classList.toggle("d-none", !isMatch)
      el.querySelectorAll("select, input").forEach((field) => {
        field.disabled = !isMatch
      })
    })

    const payloadKind = defn.payload_kind || ""
    if (this.hasSystemModeSectionTarget) {
      const showMode = payloadKind === "system_mode"
      this.systemModeSectionTarget.classList.toggle("d-none", !showMode)
      this.systemModeSectionTarget.querySelectorAll("select, input").forEach((field) => {
        field.disabled = !showMode
      })
    }

    if (this.hasConfigValueSectionTarget) {
      const showConfig = payloadKind === "config_value"
      this.configValueSectionTarget.classList.toggle("d-none", !showConfig)
      if (showConfig) {
        this.updateConfigUI()
      } else {
        this.configValueSectionTarget.querySelectorAll("select, input").forEach((field) => {
          field.disabled = true
        })
      }
    }
  }

  updateConfigUI() {
    if (!this.hasConfigSelectTarget || !this.hasConfigValueSectionTarget) return
    if (this.configValueSectionTarget.classList.contains("d-none")) return

    const confId = this.configSelectTarget.value
    const meta = this.configsValue[confId]

    if (this.hasConfigInfoTarget) {
      this.configInfoTarget.classList.toggle("d-none", !meta)
    }
    if (meta && this.hasConfigCurrentValueTarget) {
      this.configCurrentValueTarget.textContent = `${meta.value} (${meta.value_type})`
    }
    if (meta && this.hasConfigDescriptionTarget) {
      this.configDescriptionTarget.textContent = meta.description || ""
    }

    const isBoolean = meta && meta.value_type === "boolean"
    if (this.hasConfigBooleanWrapperTarget) {
      this.configBooleanWrapperTarget.classList.toggle("d-none", !isBoolean)
    }
    if (this.hasConfigTextWrapperTarget) {
      this.configTextWrapperTarget.classList.toggle("d-none", isBoolean)
    }
    if (this.hasConfigBooleanInputTarget) {
      this.configBooleanInputTarget.disabled = !isBoolean
    }
    if (this.hasConfigTextInputTarget) {
      this.configTextInputTarget.disabled = isBoolean
    }
  }

  applyOffset(event) {
    event.preventDefault()
    if (!this.hasScheduledAtInputTarget) return
    const minutes = parseInt(event.currentTarget.dataset.minutes, 10)
    if (Number.isNaN(minutes)) return

    const targetDate = new Date(Date.now() + this._clientOffsetMs + minutes * 60000)
    this.scheduledAtInputTarget.value = this._formatDatetimeLocal(targetDate)
  }

  applyTodayTime(event) {
    event.preventDefault()
    if (!this.hasScheduledAtInputTarget) return
    const timeStr = event.currentTarget.dataset.time
    if (!timeStr || !/^\d{2}:\d{2}$/.test(timeStr)) return

    const [hh, mm] = timeStr.split(":").map((v) => parseInt(v, 10))
    const nowServer = new Date(Date.now() + this._clientOffsetMs)
    const targetDate = new Date(nowServer.getTime())
    targetDate.setHours(hh, mm, 0, 0)
    if (targetDate.getTime() <= nowServer.getTime()) {
      targetDate.setDate(targetDate.getDate() + 1)
    }
    this.scheduledAtInputTarget.value = this._formatDatetimeLocal(targetDate)
  }

  _startClock() {
    if (!this.hasServerClockTarget) return
    const renderClock = () => {
      const now = new Date(Date.now() + this._clientOffsetMs)
      const yyyy = now.getFullYear()
      const mo = String(now.getMonth() + 1).padStart(2, "0")
      const dd = String(now.getDate()).padStart(2, "0")
      const hh = String(now.getHours()).padStart(2, "0")
      const mi = String(now.getMinutes()).padStart(2, "0")
      const ss = String(now.getSeconds()).padStart(2, "0")
      this.serverClockTarget.textContent = `${yyyy}-${mo}-${dd} ${hh}:${mi}:${ss}`
    }
    renderClock()
    this._clockTimer = setInterval(renderClock, 1000)
  }

  _formatDatetimeLocal(date) {
    const yyyy = date.getFullYear()
    const mo = String(date.getMonth() + 1).padStart(2, "0")
    const dd = String(date.getDate()).padStart(2, "0")
    const hh = String(date.getHours()).padStart(2, "0")
    const mi = String(date.getMinutes()).padStart(2, "0")
    return `${yyyy}-${mo}-${dd}T${hh}:${mi}`
  }
}
