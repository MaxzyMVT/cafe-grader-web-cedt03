import { Controller } from "@hotwired/stimulus"

const ROW_HEIGHT = 42
const COL_WIDTH = 56
const ROW_OVERSCAN = 8
const COL_OVERSCAN = 6
const RANK_COL_W = 68
const NAME_COL_W = 210
const SUM_COL_W = 86
const BONUS_COL_W = 74
const DEDUCTED_COL_W = 82

function formatScore(val) {
  if (val === null || val === undefined) return ""
  const rounded = Math.round(Number(val) * 100) / 100
  if (Number.isInteger(rounded)) return String(rounded)
  return rounded.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")
}

function rankClassFor(rank) {
  if (rank === 1) return "sb-rank-1"
  if (rank === 2) return "sb-rank-2"
  if (rank === 3) return "sb-rank-3"
  return "sb-rank-default"
}

export default class extends Controller {
  static targets = [
    "searchInput",
    "data",
    "scrollWrapper",
    "table",
    "thead",
    "tbody",
    "entityCount",
    "problemCount",
    "csvLink"
  ]

  initialize() {
    this._payload = null
    this._filteredRows = []
    this._dataVersion = 0
    this._lastRange = null
    this._rafId = null
    this._boundOnScroll = () => this._scheduleRender()
    this._resizeObserver = null
    this._attachedEl = null
  }

  connect() {
    if (!this._payload) {
      this._loadFromDataTarget()
    }
    if (!this._attachedEl) {
      this._attachScrollListeners()
    }
    this._render(true)

    if (this.element.id === "scoreboard-container") {
      this.interval = setInterval(() => {
        if (document.visibilityState === "visible") {
          this.refresh()
        }
      }, 30000)
    }
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
    this._detachScrollListeners()
    if (this._rafId) {
      cancelAnimationFrame(this._rafId)
      this._rafId = null
    }
  }

  dataTargetConnected() {
    this._loadFromDataTarget()
  }

  scrollWrapperTargetConnected() {
    this._attachScrollListeners()
    this._render(true)
  }

  scrollWrapperTargetDisconnected() {
    this._detachScrollListeners()
  }

  filterRows() {
    this._applyFilter()
    if (this.hasScrollWrapperTarget) {
      this.scrollWrapperTarget.scrollTop = 0
    }
    this._render(true)
  }

  async refresh() {
    if (this.element.id !== "scoreboard-container") return

    try {
      const url = new URL(window.location.href)
      if (!url.pathname.endsWith(".json")) {
        url.pathname = `${url.pathname.replace(/\/$/, "")}.json`
      }
      const response = await fetch(url.toString(), {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      if (!response.ok) return

      const payload = await response.json()
      this._setPayload(payload, false)
    } catch (_e) {
      // Silent retry on next interval
    }
  }

  _loadFromDataTarget() {
    if (!this.hasDataTarget) return
    try {
      const parsed = JSON.parse(this.dataTarget.textContent || "{}")
      this._setPayload(parsed, true)
    } catch (_e) {
      this._payload = null
    }
  }

  _setPayload(payload, resetScroll) {
    this._payload = this._preparePayload(payload)
    this._dataVersion += 1
    this._applyFilter()
    this._updateBadges()
    this._updateCsvLink()

    if (resetScroll && this.hasScrollWrapperTarget) {
      this.scrollWrapperTarget.scrollTop = 0
      this.scrollWrapperTarget.scrollLeft = 0
    }
    this._render(true)
  }

  _preparePayload(raw) {
    const problems = (raw.problems || []).map((p) => ({
      ...p,
      scopeSet: new Set(p.scope_ids || []),
      fbMap: new Map((p.fb_users || []).map((uid, idx) => [uid, idx]))
    }))

    const rows = (raw.rows || []).map((r) => ({
      ...r,
      scopeSet: new Set(r.sc || []),
      zpSet: new Set(r.zp || [])
    }))

    return {
      mode: raw.mode || "individual",
      contest_mode: Boolean(raw.contest_mode),
      contest_names: raw.contest_names || [],
      group_score_type: raw.group_score_type || "group_sum",
      enable_bonus: Boolean(raw.enable_bonus),
      enable_penalty: Boolean(raw.enable_penalty),
      show_first_bloods: Boolean(raw.show_first_bloods),
      total_entities: raw.total_entities || 0,
      problems,
      rows
    }
  }

  _applyFilter() {
    if (!this._payload) {
      this._filteredRows = []
      return
    }
    const query = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ""
    if (!query) {
      this._filteredRows = this._payload.rows
    } else {
      this._filteredRows = this._payload.rows.filter((r) => (r.sn || "").includes(query))
    }
  }

  _updateBadges() {
    if (!this._payload) return
    if (this.hasEntityCountTarget) {
      const label = this._payload.mode === "group" ? "Groups" : "Participants"
      this.entityCountTarget.textContent = `${this._payload.total_entities} ${label}`
    }
    if (this.hasProblemCountTarget) {
      this.problemCountTarget.textContent = `${this._payload.problems.length} Problems`
    }
  }

  _updateCsvLink() {
    if (!this.hasCsvLinkTarget || !this._payload) return
    const currentUrl = new URL(window.location.href)
    const csvUrl = new URL(this.csvLinkTarget.href, window.location.origin)
    csvUrl.searchParams.set("mode", this._payload.mode)
    const sortVal = currentUrl.searchParams.get("sort")
    if (sortVal) {
      csvUrl.searchParams.set("sort", sortVal)
    } else {
      csvUrl.searchParams.delete("sort")
    }
    this.csvLinkTarget.href = csvUrl.pathname + csvUrl.search
  }

  _attachScrollListeners() {
    this._detachScrollListeners()
    if (!this.hasScrollWrapperTarget) return

    const el = this.scrollWrapperTarget
    el.addEventListener("scroll", this._boundOnScroll, { passive: true })
    if (typeof ResizeObserver !== "undefined") {
      this._resizeObserver = new ResizeObserver(() => this._scheduleRender())
      this._resizeObserver.observe(el)
    }
    this._attachedEl = el
  }

  _detachScrollListeners() {
    if (this._attachedEl) {
      this._attachedEl.removeEventListener("scroll", this._boundOnScroll)
      this._attachedEl = null
    }
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    }
  }

  _scheduleRender() {
    if (this._rafId) return
    this._rafId = requestAnimationFrame(() => {
      this._rafId = null
      this._render(false)
    })
  }

  _isUserAssociated(row, problem) {
    if (row.adm) return true
    if (this._payload.contest_mode) {
      if (row.scopeSet.size === 0 || problem.scopeSet.size === 0) return false
      for (const cid of row.scopeSet) {
        if (problem.scopeSet.has(cid)) return true
      }
      return false
    }
    if (!problem.restricted) return true
    for (const gid of row.scopeSet) {
      if (problem.scopeSet.has(gid)) return true
    }
    return false
  }

  _isGroupAssociated(row, problem) {
    if (this._payload.contest_mode) return true
    if (!problem.restricted) return true
    return problem.scopeSet.has(row.id)
  }

  _render(force) {
    if (!this._payload || !this.hasScrollWrapperTarget || !this.hasTableTarget || !this.hasTheadTarget || !this.hasTbodyTarget) {
      return
    }

    const p = this._payload
    const scrollEl = this.scrollWrapperTarget
    const scrollTop = scrollEl.scrollTop
    const scrollLeft = scrollEl.scrollLeft
    const clientHeight = scrollEl.clientHeight || 600
    const clientWidth = scrollEl.clientWidth || 1200

    const bonusW = p.enable_bonus ? BONUS_COL_W : 0
    const deductedW = p.enable_penalty ? DEDUCTED_COL_W : 0
    const stickyWidth = window.innerWidth > 768 ? (RANK_COL_W + NAME_COL_W + SUM_COL_W) : 0
    const leftColsWidth = RANK_COL_W + NAME_COL_W + SUM_COL_W + bonusW + deductedW

    const totalCols = p.problems.length
    const totalRows = this._filteredRows.length

    // Calculate visible problem column slice
    let startCol = 0
    let endCol = totalCols
    if (totalCols > 32) {
      const rawStart = Math.floor((scrollLeft + stickyWidth - leftColsWidth) / COL_WIDTH)
      const rawEnd = Math.ceil((scrollLeft + clientWidth - leftColsWidth) / COL_WIDTH)
      startCol = Math.max(0, rawStart - COL_OVERSCAN)
      endCol = Math.min(totalCols, rawEnd + COL_OVERSCAN)
    }

    // Calculate visible row slice
    const headerH = this.theadTarget.offsetHeight || 130
    let startRow = 0
    let endRow = totalRows
    if (totalRows > 50) {
      const rawStartRow = Math.floor((scrollTop - headerH) / ROW_HEIGHT)
      const rawEndRow = Math.ceil((scrollTop + clientHeight) / ROW_HEIGHT)
      startRow = Math.max(0, rawStartRow - ROW_OVERSCAN)
      endRow = Math.min(totalRows, rawEndRow + ROW_OVERSCAN)
    }

    const last = this._lastRange
    const colsChanged = force || !last || last.startCol !== startCol || last.endCol !== endCol || last.version !== this._dataVersion
    const rowsChanged = force || !last || last.startRow !== startRow || last.endRow !== endRow || last.version !== this._dataVersion

    if (!colsChanged && !rowsChanged) return

    this._lastRange = { startRow, endRow, startCol, endCol, version: this._dataVersion }

    const leftSpacerW = startCol * COL_WIDTH
    const rightSpacerW = (totalCols - endCol) * COL_WIDTH
    const totalTableW = leftColsWidth + totalCols * COL_WIDTH
    this.tableTarget.style.width = `${totalTableW}px`

    const fixedColCount = 3 + (p.enable_bonus ? 1 : 0) + (p.enable_penalty ? 1 : 0)
    const renderedColCount = fixedColCount + (leftSpacerW > 0 ? 1 : 0) + (endCol - startCol) + (rightSpacerW > 0 ? 1 : 0)

    if (colsChanged) {
      this._renderHeader(p, startCol, endCol, leftSpacerW, rightSpacerW)
    }

    this._renderBody(p, startRow, endRow, startCol, endCol, leftSpacerW, rightSpacerW, renderedColCount)
  }

  _renderHeader(p, startCol, endCol, leftSpacerW, rightSpacerW) {
    const tr = document.createElement("tr")

    const thRank = document.createElement("th")
    thRank.className = "text-center sb-col-rank"
    thRank.textContent = "Rank"
    tr.appendChild(thRank)

    const thName = document.createElement("th")
    thName.className = "sb-col-name"
    thName.textContent = p.mode === "group" ? "Group / Member" : "Participant"
    tr.appendChild(thName)

    const thSum = document.createElement("th")
    thSum.className = "text-center sb-col-sum"
    thSum.textContent = "Sum"
    tr.appendChild(thSum)

    if (p.enable_bonus) {
      const thBonus = document.createElement("th")
      thBonus.className = "text-center sb-col-bonus"
      thBonus.textContent = "Bonus"
      tr.appendChild(thBonus)
    }

    if (p.enable_penalty) {
      const thDed = document.createElement("th")
      thDed.className = "text-center sb-col-deducted"
      thDed.textContent = "Deducted"
      tr.appendChild(thDed)
    }

    if (leftSpacerW > 0) {
      const thLeft = document.createElement("th")
      thLeft.className = "sb-col-spacer"
      thLeft.style.width = `${leftSpacerW}px`
      tr.appendChild(thLeft)
    }

    for (let i = startCol; i < endCol; i++) {
      const prob = p.problems[i]
      const th = document.createElement("th")
      th.className = "text-center problem-header"
      if (prob.full_name) th.title = prob.full_name

      const vText = document.createElement("div")
      vText.className = "vertical-text"
      vText.textContent = prob.name
      th.appendChild(vText)

      const fullDiv = document.createElement("div")
      fullDiv.className = "small text-muted fw-normal"
      fullDiv.textContent = String(prob.full_score ?? 100)
      th.appendChild(fullDiv)

      if (p.show_first_bloods && prob.fb_bonus !== 0 && prob.fb_n > 0) {
        const badge = document.createElement("div")
        badge.className = "badge bg-danger-subtle text-danger border border-danger-subtle px-1 py-0 mt-1"
        badge.style.fontSize = "0.68rem"
        badge.title = `First ${prob.fb_n} Bloods Bonus: ${prob.fb_bonus}`

        const icon = document.createElement("span")
        icon.className = "mi"
        icon.style.fontSize = "0.75rem"
        icon.textContent = "bloodtype"
        badge.appendChild(icon)

        const formattedBonus = prob.fb_bonus > 0 ? `+${formatScore(prob.fb_bonus)}` : formatScore(prob.fb_bonus)
        const valSpan = document.createElement("span")
        valSpan.textContent = formattedBonus
        badge.appendChild(valSpan)

        th.appendChild(badge)
      }

      tr.appendChild(th)
    }

    if (rightSpacerW > 0) {
      const thRight = document.createElement("th")
      thRight.className = "sb-col-spacer"
      thRight.style.width = `${rightSpacerW}px`
      tr.appendChild(thRight)
    }

    this.theadTarget.replaceChildren(tr)
  }

  _renderBody(p, startRow, endRow, startCol, endCol, leftSpacerW, rightSpacerW, renderedColCount) {
    const frag = document.createDocumentFragment()
    const totalRows = this._filteredRows.length

    if (totalRows === 0) {
      const tr = document.createElement("tr")
      tr.className = "sb-empty-row"
      const td = document.createElement("td")
      td.colSpan = Math.max(1, renderedColCount)
      td.className = "text-center text-muted py-5"

      const icon = document.createElement("span")
      icon.className = "mi md-36 d-block mb-2 opacity-50"
      icon.textContent = "leaderboard"
      td.appendChild(icon)

      const hasQuery = this.hasSearchInputTarget && this.searchInputTarget.value.trim().length > 0
      const msg = document.createTextNode(hasQuery ? "No matching participants found." : "No entries to display yet.")
      td.appendChild(msg)

      tr.appendChild(td)
      frag.appendChild(tr)
      this.tbodyTarget.replaceChildren(frag)
      return
    }

    // Top spacer row
    if (startRow > 0) {
      const topTr = document.createElement("tr")
      topTr.className = "sb-spacer-row"
      topTr.setAttribute("aria-hidden", "true")
      const topTd = document.createElement("td")
      topTd.colSpan = renderedColCount
      topTd.style.height = `${startRow * ROW_HEIGHT}px`
      topTr.appendChild(topTd)
      frag.appendChild(topTr)
    }

    // Visible rows
    for (let rIdx = startRow; rIdx < endRow; rIdx++) {
      const row = this._filteredRows[rIdx]
      const tr = document.createElement("tr")

      if (row.t === "g") {
        tr.className = "scoreboard-group-row"
        this._fillGroupRow(tr, p, row, startCol, endCol, leftSpacerW, rightSpacerW)
      } else {
        if (row.self) tr.className = "scoreboard-row-self"
        this._fillUserRow(tr, p, row, startCol, endCol, leftSpacerW, rightSpacerW)
      }

      frag.appendChild(tr)
    }

    // Bottom spacer row
    const remainingRows = totalRows - endRow
    if (remainingRows > 0) {
      const botTr = document.createElement("tr")
      botTr.className = "sb-spacer-row"
      botTr.setAttribute("aria-hidden", "true")
      const botTd = document.createElement("td")
      botTd.colSpan = renderedColCount
      botTd.style.height = `${remainingRows * ROW_HEIGHT}px`
      botTr.appendChild(botTd)
      frag.appendChild(botTr)
    }

    this.tbodyTarget.replaceChildren(frag)
  }

  _fillUserRow(tr, p, row, startCol, endCol, leftSpacerW, rightSpacerW) {
    // 1. Rank
    const tdRank = document.createElement("td")
    if (row.t === "m") {
      tdRank.className = "text-center text-muted small sb-col-rank font-monospace"
      tdRank.textContent = `#${row.r}`
    } else {
      tdRank.className = "text-center sb-col-rank"
      const pill = document.createElement("span")
      pill.className = `sb-rank-pill ${rankClassFor(row.r)}`
      pill.textContent = String(row.r)
      tdRank.appendChild(pill)
    }
    tr.appendChild(tdRank)

    // 2. Name
    const tdName = document.createElement("td")
    tdName.className = row.t === "m" ? "ps-3 sb-col-name" : "sb-col-name"
    tdName.title = row.n

    const nameWrap = document.createElement("div")
    nameWrap.className = row.t === "m" ? "d-flex align-items-center gap-1 min-w-0" : "d-flex align-items-center gap-2 min-w-0"

    if (row.t === "m") {
      const subIcon = document.createElement("span")
      subIcon.className = "mi md-16 text-muted flex-shrink-0"
      subIcon.textContent = "subdirectory_arrow_right"
      nameWrap.appendChild(subIcon)
    }

    const nameSpan = document.createElement("span")
    nameSpan.className = (row.self || (row.t === "u" && row.r <= 3)) ? "sb-name-truncate fw-bold" : "sb-name-truncate"
    nameSpan.textContent = row.n
    nameWrap.appendChild(nameSpan)

    if (row.self) {
      const youBadge = document.createElement("span")
      youBadge.className = "badge rounded-pill bg-primary flex-shrink-0"
      youBadge.style.fontSize = "0.68rem"
      youBadge.textContent = "You"
      nameWrap.appendChild(youBadge)
    }
    tdName.appendChild(nameWrap)
    tr.appendChild(tdName)

    // 3. Sum
    const tdSum = document.createElement("td")
    tdSum.className = row.t === "m" ? "text-center sb-col-sum font-monospace" : "text-center fw-bold sb-col-sum font-monospace"
    tdSum.textContent = formatScore(row.s)
    tr.appendChild(tdSum)

    // 4. Optional Bonus
    if (p.enable_bonus) {
      const tdBonus = document.createElement("td")
      tdBonus.className = row.t === "m" ? "text-center text-success font-monospace sb-col-bonus" : "text-center text-success fw-semibold font-monospace sb-col-bonus"
      if (row.b > 0) tdBonus.textContent = `+${formatScore(row.b)}`
      tr.appendChild(tdBonus)
    }

    // 5. Optional Deducted
    if (p.enable_penalty) {
      const tdDed = document.createElement("td")
      tdDed.className = row.t === "m" ? "text-center text-danger font-monospace sb-col-deducted" : "text-center text-danger fw-semibold font-monospace sb-col-deducted"
      if (row.d > 0) tdDed.textContent = `-${formatScore(row.d)}`
      tr.appendChild(tdDed)
    }

    // Left spacer column
    if (leftSpacerW > 0) {
      const tdLeft = document.createElement("td")
      tdLeft.className = "sb-col-spacer"
      tr.appendChild(tdLeft)
    }

    // Visible problem score cells
    const rowScores = row.p || {}
    for (let i = startCol; i < endCol; i++) {
      const prob = p.problems[i]
      const td = document.createElement("td")
      td.className = "text-center score-cell"

      if (this._isUserAssociated(row, prob)) {
        const key = String(i)
        if (Object.prototype.hasOwnProperty.call(rowScores, key)) {
          const score = Number(rowScores[key]) || 0
          const fullScore = Number(prob.full_score ?? 100)
          const isZeroPass = fullScore === 0 && row.zpSet.has(i)
          const pct = isZeroPass ? 1.0 : (Math.abs(fullScore) > 0 ? Math.min(1, Math.max(0, Math.abs(score) / Math.abs(fullScore))) : 0)

          let chipClass
          if (isZeroPass || pct >= 1.0) {
            chipClass = "score-chip--full"
          } else if (pct >= 0.5) {
            chipClass = "score-chip--high"
          } else if (score > 0) {
            chipClass = "score-chip--partial"
          } else {
            chipClass = "score-chip--zero"
          }

          const chip = document.createElement("span")
          chip.className = `score-chip ${chipClass}`
          chip.textContent = formatScore(score)

          if (p.show_first_bloods && prob.fb_bonus !== 0 && prob.fbMap.has(row.id)) {
            const idx = prob.fbMap.get(row.id)
            const fbIcon = document.createElement("span")
            fbIcon.className = "mi text-danger sb-fb-icon"
            const formattedBonus = prob.fb_bonus > 0 ? `+${formatScore(prob.fb_bonus)}` : formatScore(prob.fb_bonus)
            fbIcon.title = `Blood Winner #${idx + 1}! Received ${formattedBonus} bonus!`
            fbIcon.textContent = "bloodtype"
            chip.appendChild(fbIcon)
          }

          td.appendChild(chip)
        } else {
          const dot = document.createElement("span")
          dot.className = "score-chip--unattempted"
          dot.textContent = "·"
          td.appendChild(dot)
        }
      } else {
        const dash = document.createElement("span")
        dash.className = "score-chip--unattempted"
        dash.textContent = "—"
        td.appendChild(dash)
      }

      tr.appendChild(td)
    }

    // Right spacer column
    if (rightSpacerW > 0) {
      const tdRight = document.createElement("td")
      tdRight.className = "sb-col-spacer"
      tr.appendChild(tdRight)
    }
  }

  _fillGroupRow(tr, p, row, startCol, endCol, leftSpacerW, rightSpacerW) {
    // 1. Rank
    const tdRank = document.createElement("td")
    tdRank.className = "text-center sb-col-rank"
    const pill = document.createElement("span")
    pill.className = `sb-rank-pill ${rankClassFor(row.r)}`
    pill.textContent = String(row.r)
    tdRank.appendChild(pill)
    tr.appendChild(tdRank)

    // 2. Group name
    const tdName = document.createElement("td")
    tdName.className = "sb-col-name"
    tdName.title = row.n

    const nameWrap = document.createElement("div")
    nameWrap.className = "d-flex align-items-center gap-2 min-w-0"

    const gIcon = document.createElement("span")
    gIcon.className = "mi md-18 text-primary flex-shrink-0"
    gIcon.textContent = "groups"
    nameWrap.appendChild(gIcon)

    const nameSpan = document.createElement("span")
    nameSpan.className = "sb-name-truncate fw-bold"
    nameSpan.textContent = row.n
    nameWrap.appendChild(nameSpan)

    const cntBadge = document.createElement("span")
    cntBadge.className = "badge rounded-pill bg-secondary-subtle text-secondary flex-shrink-0"
    cntBadge.style.fontSize = "0.7rem"
    cntBadge.textContent = String(row.cnt || 0)
    nameWrap.appendChild(cntBadge)

    tdName.appendChild(nameWrap)
    tr.appendChild(tdName)

    // 3. Sum
    const tdSum = document.createElement("td")
    tdSum.className = "text-center fw-bold sb-col-sum font-monospace"
    tdSum.textContent = formatScore(row.s)
    tr.appendChild(tdSum)

    // 4. Optional Bonus
    if (p.enable_bonus) {
      const tdBonus = document.createElement("td")
      tdBonus.className = "text-center text-success fw-bold font-monospace sb-col-bonus"
      if (row.b > 0) tdBonus.textContent = `+${formatScore(row.b)}`
      tr.appendChild(tdBonus)
    }

    // 5. Optional Deducted
    if (p.enable_penalty) {
      const tdDed = document.createElement("td")
      tdDed.className = "text-center text-danger fw-bold font-monospace sb-col-deducted"
      if (row.d > 0) tdDed.textContent = `-${formatScore(row.d)}`
      tr.appendChild(tdDed)
    }

    // Left spacer
    if (leftSpacerW > 0) {
      const tdLeft = document.createElement("td")
      tdLeft.className = "sb-col-spacer"
      tr.appendChild(tdLeft)
    }

    // Visible problem cells
    const rowScores = row.p || {}
    for (let i = startCol; i < endCol; i++) {
      const prob = p.problems[i]
      const td = document.createElement("td")
      td.className = "text-center score-cell fw-bold font-monospace"

      if (this._isGroupAssociated(row, prob)) {
        const key = String(i)
        if (Object.prototype.hasOwnProperty.call(rowScores, key) && Number(rowScores[key]) > 0) {
          td.textContent = formatScore(rowScores[key])
        } else {
          const dot = document.createElement("span")
          dot.className = "score-chip--unattempted"
          dot.textContent = "·"
          td.appendChild(dot)
        }
      } else {
        const dash = document.createElement("span")
        dash.className = "score-chip--unattempted"
        dash.textContent = "—"
        td.appendChild(dash)
      }

      tr.appendChild(td)
    }

    // Right spacer
    if (rightSpacerW > 0) {
      const tdRight = document.createElement("td")
      tdRight.className = "sb-col-spacer"
      tr.appendChild(tdRight)
    }
  }
}
