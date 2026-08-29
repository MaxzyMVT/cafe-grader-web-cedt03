import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    url: String,                // The URL template to send the reorder request to (contains -123 placeholder)
    reloadType: String,         // "page" if we should reload the entire page after reorder
    recordParamName: String,    // If set (e.g. "problem_id"), will send this as form param instead of replacing -123 in URL
    additionalParams: Object    // Any additional parameters (e.g. { command: "reorder" })
  }

  connect() {
    this.dragStartHandler = this.dragStart.bind(this);
    this.dragOverHandler = this.dragOver.bind(this);
    this.dragEndHandler = this.dragEnd.bind(this);
    this.dropHandler = this.drop.bind(this);

    this.element.addEventListener("dragstart", this.dragStartHandler);
    this.element.addEventListener("dragover", this.dragOverHandler);
    this.element.addEventListener("dragend", this.dragEndHandler);
    this.element.addEventListener("drop", this.dropHandler);
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.dragStartHandler);
    this.element.removeEventListener("dragover", this.dragOverHandler);
    this.element.removeEventListener("dragend", this.dragEndHandler);
    this.element.removeEventListener("drop", this.dropHandler);
  }

  dragStart(event) {
    const tr = event.target.closest("tr");
    if (!tr) return;
    this.draggedRow = tr;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", tr.id);
    tr.classList.add("dragging");
  }

  dragOver(event) {
    event.preventDefault();
    const draggedRow = this.draggedRow;
    if (!draggedRow) return;
    const targetRow = event.target.closest("tr");
    if (targetRow && targetRow !== draggedRow && targetRow.parentNode === draggedRow.parentNode) {
      const parent = targetRow.parentNode;
      const position = draggedRow.compareDocumentPosition(targetRow);
      if (position & Node.DOCUMENT_POSITION_FOLLOWING) {
        parent.insertBefore(draggedRow, targetRow.nextSibling);
      } else if (position & Node.DOCUMENT_POSITION_PRECEDING) {
        parent.insertBefore(draggedRow, targetRow);
      }
    }
  }

  dragEnd(event) {
    if (this.draggedRow) {
      this.draggedRow.classList.remove("dragging");
    }
  }

  async drop(event) {
    event.preventDefault();
    const draggedRow = this.draggedRow;
    if (!draggedRow) return;

    // Find the new 1-indexed position in the table body
    const siblings = Array.from(draggedRow.parentNode.querySelectorAll("tr"));
    const newIndex = siblings.indexOf(draggedRow) + 1;

    let recordId = draggedRow.dataset.rowId;
    if (!recordId && draggedRow.id) {
      const match = draggedRow.id.match(/\d+/);
      if (match) recordId = match[0];
    }

    if (!recordId) return;

    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
    
    // Construct the URL
    let url = this.urlValue;
    if (!this.hasRecordParamNameValue || this.recordParamNameValue === "") {
      url = url.replace("-123", recordId);
    }

    const body = new FormData();
    body.append("target_position", newIndex);

    if (this.hasRecordParamNameValue && this.recordParamNameValue !== "") {
      body.append(this.recordParamNameValue, recordId);
    }

    if (this.hasAdditionalParamsValue) {
      for (const [key, value] of Object.entries(this.additionalParamsValue)) {
        body.append(key, value);
      }
    }

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        },
        body: body
      });

      if (response.ok) {
        const html = await response.text();
        Turbo.renderStreamMessage(html);

        if (this.hasReloadTypeValue && this.reloadTypeValue === "page") {
          const table = this.element.tagName === "TABLE"
            ? this.element
            : this.element.querySelector("table");
          const tbody = table?.querySelector("tbody");
          if (tbody) {
            Array.from(tbody.querySelectorAll("tr")).forEach((row, index) => {
              const firstCell = row.querySelector("td");
              if (firstCell) firstCell.textContent = index + 1;
            });
          }
        }
      } else {
        console.error("Failed to update order");
      }
    } catch (err) {
      console.error("Error updating order:", err);
    } finally {
      this.draggedRow = null;
    }
  }
}
