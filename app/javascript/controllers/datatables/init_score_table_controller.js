import DatatableInitController from "controllers/datatables/init_controller"
import { columns, renderers } from 'controllers/datatables/columns'
import "chart" // UMD build: sets window.Chart as side effect

/**
 * init datatable for contest/view.htlm.haml
 */
export default class extends DatatableInitController {
  static values = { 
    showDeduction: {type: Boolean, default: true},
    enableAbsentFilter: {type: Boolean, default: false},
    problemIds: Array,
    submissionPath: String,
    submissionDownloadPath: String,
    statPath: String,
    refreshSubmitFormId: String,
  }

  static targets = [ "showLoad", "showDeduction", "hideAbsent", "problemScore", "totalScore",
                     "problemScoreChartContainer", "totalScoreChartContainer",
                     "probHeader"]

  connect() {
    this._absentFilterFn = (settings, _searchData, dataIndex, rowData) => {
      if (!this.tables || !this.tables.some(t => t.settings()[0] === settings)) {
        return true
      }
      if (this.hasHideAbsentTarget && this.hideAbsentTarget.checked) {
        const data = rowData || settings.aoData[dataIndex]?._aData
        return !!(data && data.last_heartbeat)
      }
      return true
    }
    $.fn.dataTable.ext.search.push(this._absentFilterFn)
    super.connect()
  }

  disconnect() {
    if (this._absentFilterFn) {
      const idx = $.fn.dataTable.ext.search.indexOf(this._absentFilterFn)
      if (idx !== -1) $.fn.dataTable.ext.search.splice(idx, 1)
    }
    if (typeof this.problemScoreChart !== 'undefined') { this.problemScoreChart.destroy() }
    if (typeof this.totalScoreChart !== 'undefined') { this.totalScoreChart.destroy() }
  }

  // -------   draw graph -----------
  // call chart.js
  // json is the response from the controller {data: ..., result:..., problem: ...}
  _drawGraph(json) {
    window.graphData = json
    const styles = getComputedStyle(document.body)
    const textColor = styles.getPropertyValue('--bs-body-color').trim() || '#333333'
    const gridColor = styles.getPropertyValue('--bs-border-color').trim() || 'rgba(128,128,128,0.2)'

    //build dataset
    const usersCount = json.data.length
    let data = {
      labels: Array.from(Array(usersCount), (_, i) => i+1), //this builds [1,2,3,4,....,N]
      datasets:
        json.problem.map( (a) => {
          return {
            label: a.name,
            data: json.data.map( (b) => parseFloat(b[`final_score_${a.id}`]) || 0).sort( (a,b) => a-b )
          }
        })
    }

    //left pad each dataset with zero
    let maxLength = data.labels.length
    data.datasets.forEach(dataset => {
      const paddingLength = maxLength - dataset.data.length;
      if (paddingLength > 0) {
          const padding = new Array(paddingLength).fill(0); // Create an array of 0's for padding
          dataset.data = [...padding, ...dataset.data]; // Prepend the 0's to the data array
      }
    });

    let config = {
      type: 'line',
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        elements: {
          point: {
            pointStyle: false
          },
        },
        plugins: {
          legend: {
            labels: { color: textColor }
          }
        },
        scales: {
          x: {
            ticks: { color: textColor },
            grid: { color: gridColor }
          },
          y: {
            ticks: { color: textColor },
            grid: { color: gridColor }
          }
        }
      },
    }

    //clone the config to be used in the second graph
    //this has to be done before we construct the chart.js object,
    //else the config is already changed
    let config2 = structuredClone(config)
    let data2 = {
      labels: Array.from(Array(usersCount), (_, i) => i+1), //this build [1,2,3,4,....,N]
      datasets: [
        {
          label: 'Total Score',
          data: json.data.map( (a) => parseFloat(a.sum_final) || 0 ).sort( (a,b) => a-b )
        }
      ]
    }
    config2.data = data2

    // destroy old graph
    if (typeof this.problemScoreChart !== 'undefined') { this.problemScoreChart.destroy() }
    if (typeof this.totalScoreChart !== 'undefined') { this.totalScoreChart.destroy() }

    // display graph
    Chart.defaults.font.size = 15
    //Chart.defaults.font.family = 'Sarabun Light'
    this.problemScoreChart = new Chart(this.problemScoreTarget,config)
    this.totalScoreChart = new Chart(this.totalScoreTarget,config2)

    if (json.data.length > 0 && json.problem.length > 0) {
      this.problemScoreChartContainerTarget.style = "height: 350px";
      this.totalScoreChartContainerTarget.style = "height: 350px";
    } else {
      this.problemScoreChartContainerTarget.style = "height: 1px";
      this.totalScoreChartContainerTarget.style = "height: 1px";
    }
  }

  // OVERRIDE: Programmatically create the columns.
  _buildColumns(baseConfig) {
    const userStatPath = this.statPathValue
    this.deductionColumns = []  // array of column indices that are raw & total cost
                                // we use this array to show/hide columns
    let count = 0
    let problemColumns = this.problemIdsValue.map( id => {
      this.deductionColumns.push(6 + 3 * count + 0) // for this problem raw
      this.deductionColumns.push(6 + 3 * count + 1) // for this problem deduction
      count += 1
      let result = []
      if (this.showDeductionValue) {
        result.push( {data: `raw_score_${id}`,className: 'text-center text-secondary' })
        result.push( {data: `total_cost_${id}`, className: 'text-center text-secondary',render: this._deduction_renderer_factory(id)})
      }
      result.push({data: `final_score_${id}`,className: 'text-center border-end',render: this._score_renderer_factory(id) })
      return result
    }).flat()
    this.deductionColumns.push(6 + 3 * count + 0) // for the summation raw

    let columns = [
      {data: 'row_number', className: 'text-center'},
      {data: 'login', render: cafe.dt.render.link(null,{path: userStatPath, replace_field: 'user_id' })},
      {data: 'full_name'},
      {data: 'remark'},
      {data: 'seat'},
      {data: 'last_heartbeat',label: 'Last Checkin', className: 'border-end', render: renderers.humanizeTimeRender},
    ].concat(problemColumns)
    if (this.showDeductionValue) {
      columns.push({data: 'sum_raw', className: 'fw-bold text-center text-secondary'})
    }
    columns.push( {data: 'sum_final', className: 'fw-bold text-center border-end'} )

    return columns
  }

  // OVERRIDE: ajax with special processing
  _buildAjaxOptions(baseConfig) {
    let ajaxOptions = super._buildAjaxOptions(baseConfig);
    // pre request processing
    ajaxOptions.data = (data) => {
      const result = $.extend({}, data, window.userFilterParams, window.problemFilterParams, window.submissionFilterParams);
      return result
    }
    // post request processing
    ajaxOptions.dataSrc = (json) => {
      const processedJson = processScore(json)
      this._lastProcessedJson = processedJson
      this._refreshChartsAndTotals()
      return processedJson.data
    }
    return ajaxOptions
  }

  //OVERRIDE: some custom config
  _buildFinalConfig(baseConfig) {
    let finalConfig = super._buildFinalConfig(baseConfig);

    // update the buttons
    // If we have this value, instead of calling ajax.refresh, we submit the form with the given ID instead
    if (this.hasRefreshSubmitFormIdValue) {
      finalConfig.buttons[0].action = (e,dt,node,config) => { document.getElementById(this.refreshSubmitFormIdValue).requestSubmit() }
    }

    const topStart = [
      'buttons',
      {
        div: {
          className: 'form-check d-inline-flex align-items-center mb-0',
          html: '<input class="form-check-input mt-0" id="show-load" name="show-load" type="checkbox" data-datatables--init-score-table-target="showLoad" data-action="datatables--init-score-table#redraw">' +
                '<label class="ms-2 form-check-label" for="show-load">Show submission time & download link</label>'
        }
      },
      {
        div: {
          className: 'form-check d-inline-flex align-items-center mb-0',
          html: `<input class="form-check-input mt-0" id="show-deduction" name="show-deduction" type="checkbox" data-datatables--init-score-table-target="showDeduction" data-action="datatables--init-score-table#redraw" ${ this.showDeductionValue ? 'checked' : ''}>` +
                '<label class="ms-2 form-check-label" for="show-deduction">Show full score deduction (by Hint & LLM)</label>'
        }
      }
    ]

    if (this.enableAbsentFilterValue) {
      topStart.push({
        div: {
          className: 'form-check d-inline-flex align-items-center mb-0',
          html: '<input class="form-check-input mt-0" id="hide-absent" name="hide-absent" type="checkbox" data-datatables--init-score-table-target="hideAbsent" data-action="datatables--init-score-table#toggleAbsent">' +
                '<label class="ms-2 form-check-label" for="hide-absent">Hide absent contestants (no Last Seen)</label>'
        }
      })
    }

    finalConfig.layout = {
      topStart: topStart,
      topEnd: 'search'
    }

    return finalConfig
  }

  toggleAbsent() {
    this._refreshChartsAndTotals()
    this.tables.forEach(table => {
      table.draw()
    })
  }

  _refreshChartsAndTotals() {
    if (!this._lastProcessedJson) return
    const hideAbsent = this.hasHideAbsentTarget && this.hideAbsentTarget.checked
    const filteredData = hideAbsent
      ? this._lastProcessedJson.data.filter(row => Boolean(row.last_heartbeat))
      : this._lastProcessedJson.data

    updateFooterTotals(this._lastProcessedJson.problem, filteredData)
    this._drawGraph({ ...this._lastProcessedJson, data: filteredData })
  }

  // generate a renderer function for rendering score / time / link for problem prob_id
  _score_renderer_factory(prob_id) {
    const subPath = this.submissionPathValue
    const subDownloadPath = this.submissionDownloadPathValue
    return (data,type,row,meta) => {
      if (!data) return ''
      if (type == 'display' || type == 'filter') {
        if (this.showLoadTarget.checked) {
          // render the score, along with the time and link to the sub
          const sub_col = `sub_${prob_id}`     // column name that contains submission number
          const time_col = `time_${prob_id}`   // column name that contains the latest submission time
          const sub_link = `<a class="text-nowrap" href=${subPath.replace(-123,row[sub_col])}>[ ${moment(row[time_col]).format('HH:mm:ss')} ]</a>`


          const st = `${data} </br> ${sub_link} | ${subDownloadPath.replace(-123,row[sub_col])}`
          return st
        } else {
          return data
        }
      }

      //for sort, we just return the data which is supposed to be iso8601
      return data
    }
  }

  // render the full score deduction columns (raw score, deduction points)
  _deduction_renderer_factory(prob_id) {
    return (data,type,row,meta) => {
      if (!data) return ''
      if (type == 'display' || type == 'filter') {
        // render the DEDUCTION, with, optionally, the detail of the deduction
        if (this.showLoadTarget.checked) {
          // llm & hint col
          const llm_cost_col = `llm_cost_${prob_id}`
          const llm_count_col = `llm_count_${prob_id}`
          const hint_cost_col = `hint_cost_${prob_id}`
          const hint_count_col = `hint_count_${prob_id}`

          let st = `${data}`
          if (row[llm_count_col] ) st = st + `<div class='text-warning small '> LLM: ${row[llm_cost_col]} (${row[llm_count_col]}) </div>`
          if (row[hint_count_col] ) st = st + `<div class='text-success small '> Hint: ${row[hint_cost_col]} (${row[hint_count_col]}) </div>`
          return st
        } else {
          return data
        }
      }

      //for sort, we just return the data which is supposed to be iso8601
      return data
    }
  }

  // redraw the table & adjust visibility
  redraw(event) {
    const showDeduction = this.showDeductionTarget.checked


    this.tables.forEach(table => {
      // set the visible + force recalculation of layout (by passing 'true' to the second arg)
      table.columns(this.deductionColumns).visible(showDeduction, false)
      table.rows().invalidate('render')
    });

    // window.xxx = this.probHeaderTargets

    // I really don't know why but I have to wait a little bit, so that the visibility is taken into account
    // before I call draw() (which also must be call twice because of reason unknown in this case) so that the colspan is correctly rendered
    setTimeout(() => {
      this.probHeaderTargets.forEach(col => { col.colSpan = (showDeduction ? 3 : 1) })
      this.tables.forEach(table => {
        table.columns.adjust().draw()
        //table.columns.adjust().draw()
      });
    }, 500); // 1000 milliseconds = 1 second
  }
}

/** 
 * main data transform function
 * json here is the payload returned from the server and the ajax property of
 * the DataTable calls this function to transform json
 * 
 * See Contest.score_report for the detail of the json but basically, it includes
 * Two major object, json.data which is an array of each row. However, it is not populated
 * with the score of the submission. The score is stored in json.result
 * This function copy some data from json.result to json.data in the correct row
 * 
 * The json.result is also transformed into a data for chart.js to be displayed as well.
 *
 * Return json.data as this function is used as a final step in ajax options of the DataTable
 */
function processScore(json) {
  //combine score into user record
  // originally, json.data[i] is the i-th row containing user data (id,login,name,remark,seat, etc)

  // the grand total of all problems and all users
  let grandTotalRaw = 0
  let grandTotalDeduction = 0
  let grandTotalFinal = 0

  let problemSumRaw = {}
  let problemSumDeduction = {}
  let problemSumFinal = {}
  json.problem.forEach ( (prob) => { 
    problemSumRaw[prob.id] = 0.0;
    problemSumDeduction[prob.id] = 0.0;
    problemSumFinal[prob.id] = 0.0;
  })

  // for each row, i.e., user
  for (let i = 0, ien = json.data.length; i < ien; i++) {
    // add place holder for row number (which will be set in the final drawing)
    const login = json.data[i].login
    // add place holder for row number (which will be set in the listenter of 'order.dt')
    json.data[i].row_number = null

    // we loop over each problems (in json.problems)
    // we also sum the score of each user here
    let sumRaw = 0.0
    let sumDeduction = 0.0
    let sumFinal = 0.0

    json.problem.forEach ( (prob) => {

      //and pluck the score of that user from the "score_table" (json.result)
      const scoreResult = json.result.score[login]

      const probId = `raw_score_${prob.id}`
      let probScore = (scoreResult) ? (scoreResult[probId] || '') : ''

      // copy the detail of the submissions

      // if we have some result (which indicates that a user has submitted something)
      json.data[i][`raw_score_${prob.id}`] = probScore
      json.data[i][`total_cost_${prob.id}`] = null
      json.data[i][`final_score_${prob.id}`] = null
      if (probScore != null && probScore !== '') {

        probScore = parseFloat(probScore).toFixed(1)
        json.data[i][`sub_${prob.id}`] = scoreResult?.[`sub_${prob.id}`]
        json.data[i][`time_${prob.id}`] = scoreResult?.[`time_${prob.id}`]
        json.data[i][`llm_count_${prob.id}`] = scoreResult?.[`llm_count_${prob.id}`]
        json.data[i][`llm_cost_${prob.id}`] = scoreResult?.[`llm_cost_${prob.id}`]
        json.data[i][`hint_count_${prob.id}`] = scoreResult?.[`hint_count_${prob.id}`]
        json.data[i][`hint_cost_${prob.id}`] = scoreResult?.[`hint_cost_${prob.id}`]
        json.data[i][`final_score_${prob.id}`] = scoreResult?.[`final_score_${prob.id}`]
        json.data[i][`total_cost_${prob.id}`] = scoreResult?.[`total_cost_${prob.id}`]
      }

      //also sum the score of this user
      const thisRaw = parseFloat(probScore || 0.0)
      const thisDeduction = parseFloat(scoreResult?.[`total_cost_${prob.id}`] || 0)
      const thisFinal = parseFloat(scoreResult?.[`final_score_${prob.id}`] || 0)
      sumRaw += thisRaw
      sumDeduction += thisDeduction
      sumFinal += thisFinal

      //also sum the score of this problem
      problemSumRaw[prob.id] += thisRaw
      problemSumDeduction[prob.id] += thisDeduction
      problemSumFinal[prob.id] += thisFinal

    })
    // sum the score to the grand total
    grandTotalRaw += sumRaw
    grandTotalDeduction += sumDeduction
    grandTotalFinal += sumFinal
    json.data[i]['sum_raw'] = sumRaw.toFixed(1)
    json.data[i]['sum_deduction'] = sumDeduction.toFixed(1)
    json.data[i]['sum_final'] = sumFinal.toFixed(1)
  }

  updateFooterTotals(json.problem, json.data)
  return json;
}

function updateFooterTotals(problems, rows) {
  let grandTotalRaw = 0
  let grandTotalFinal = 0
  let problemSumRaw = {}
  let problemSumDeduction = {}
  let problemSumFinal = {}

  problems.forEach((prob) => {
    problemSumRaw[prob.id] = 0.0
    problemSumDeduction[prob.id] = 0.0
    problemSumFinal[prob.id] = 0.0
  })

  rows.forEach((row) => {
    problems.forEach((prob) => {
      const thisRaw = parseFloat(row[`raw_score_${prob.id}`] || 0.0)
      const thisDeduction = parseFloat(row[`total_cost_${prob.id}`] || 0.0)
      const thisFinal = parseFloat(row[`final_score_${prob.id}`] || 0.0)
      problemSumRaw[prob.id] += thisRaw
      problemSumDeduction[prob.id] += thisDeduction
      problemSumFinal[prob.id] += thisFinal
    })
    grandTotalRaw += parseFloat(row['sum_raw'] || 0.0)
    grandTotalFinal += parseFloat(row['sum_final'] || 0.0)
  })

  problems.forEach((prob) => {
    $(`#sum-raw-${prob.id}`).text(Number(problemSumRaw[prob.id]).toLocaleString(undefined, { minimumFractionDigits: 1 }))
    $(`#sum-deduction-${prob.id}`).text(Number(problemSumDeduction[prob.id]).toLocaleString(undefined, { minimumFractionDigits: 1 }))
    $(`#sum-final-${prob.id}`).text(Number(problemSumFinal[prob.id]).toLocaleString(undefined, { minimumFractionDigits: 1 }))
  })
  $('#grand-total-raw').text(Number(grandTotalRaw).toLocaleString(undefined, { minimumFractionDigits: 1 }))
  $('#grand-total-final').text(Number(grandTotalFinal).toLocaleString(undefined, { minimumFractionDigits: 1 }))
}

