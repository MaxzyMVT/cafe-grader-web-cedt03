import { Controller } from "@hotwired/stimulus"
import "chart" // UMD build: sets window.Chart as side effect

// Chart presets
// Usage:
//   %canvas{ data: { controller: 'chart', chart_data_value: @chart_dataset } }
//   %canvas{ data: { controller: 'chart', chart_data_value: @dataset, chart_preset_value: 'line' } }
const PRESETS = {
  bar: {
    type: 'bar',
    options: {
      plugins: {
        legend: { display: false },
      },
    },
  },
  line: {
    type: 'line',
    options: {
      responsive: true,
      maintainAspectRatio: false,
      elements: {
        point: { pointStyle: false },
      },
    },
  },
  submission_line: {
    type: 'line',
    options: {
      aspectRatio: 9,
      plugins: {
        legend: { display: false },
      },
      scales: {
        y: {
          title: { text: '#sub', display: true },
        },
        x: {
          ticks: { maxRotation: 0 },
        },
      },
    },
  },
}

export default class extends Controller {
  static values = {
    data: Object,
    preset: { type: String, default: 'bar' },
  }

  connect() {
    // Canvas may exist before AJAX data arrives — skip if empty
    if (Object.keys(this.dataValue).length > 0) {
      this._drawChart()
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  dataValueChanged() {
    if (Object.keys(this.dataValue).length === 0) return

    if (this.chart) {
      this.chart.destroy()
    }
    this._drawChart()
  }

  _drawChart() {
    const preset = PRESETS[this.presetValue] || PRESETS.bar
    const styles = getComputedStyle(document.body)
    const textColor = styles.getPropertyValue('--bs-body-color').trim() || '#333333'
    const gridColor = styles.getPropertyValue('--bs-border-color').trim() || 'rgba(128,128,128,0.2)'

    const options = structuredClone(preset.options || {})
    options.plugins = options.plugins || {}
    options.plugins.legend = {
      ...(options.plugins.legend || {}),
      labels: { color: textColor, ...(options.plugins.legend?.labels || {}) }
    }
    options.scales = options.scales || {}
    ;['x', 'y'].forEach((axis) => {
      options.scales[axis] = options.scales[axis] || {}
      options.scales[axis].ticks = { color: textColor, ...(options.scales[axis].ticks || {}) }
      options.scales[axis].grid = { color: gridColor, ...(options.scales[axis].grid || {}) }
      if (options.scales[axis].title) {
        options.scales[axis].title = { color: textColor, ...options.scales[axis].title }
      }
    })

    Chart.defaults.font.size = 15
    Chart.defaults.color = textColor
    this.chart = new Chart(this.element, {
      type: preset.type,
      data: this.dataValue,
      options: options,
    })
  }
}
