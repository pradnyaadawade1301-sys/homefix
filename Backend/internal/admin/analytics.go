package admin

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/models"
)

// dateRange resolves ?from=&to= (YYYY-MM-DD) query params, defaulting to the
// trailing 30 days — used by both the on-screen report and the CSV export so
// they always agree on what "the period" means.
func dateRange(c *gin.Context) (string, string) {
	to := c.Query("to")
	from := c.Query("from")
	if to == "" {
		to = time.Now().Format("2006-01-02")
	}
	if from == "" {
		from = time.Now().AddDate(0, 0, -30).Format("2006-01-02")
	}
	return from, to
}

func (d *Deps) handleAnalytics(c *gin.Context) {
	from, to := dateRange(c)
	ctx := c.Request.Context()

	revenue, err := d.Analytics.Revenue(ctx, from, to)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	dailyRevenue, _ := d.Analytics.DailyRevenue(ctx, from, to)
	dailyBookings, _ := d.Analytics.DailyBookings(ctx, from, to)
	dailySignups, _ := d.Analytics.DailySignups(ctx, from, to)

	const content = `
<form method="get" style="margin-bottom:16px">
  <label>From <input type="text" name="from" value="{{.From}}" placeholder="YYYY-MM-DD" style="width:130px;display:inline-block"></label>
  <label>To <input type="text" name="to" value="{{.To}}" placeholder="YYYY-MM-DD" style="width:130px;display:inline-block"></label>
  <button class="btn btn-sm" type="submit">Apply</button>
  <a class="btn btn-sm" href="/admin/analytics/export.csv?from={{.From}}&to={{.To}}">Export CSV</a>
</form>

<div class="cards">
  <div class="card"><div class="label">Total Revenue</div><div class="value">₹{{printf "%.0f" .Revenue.TotalRevenue}}</div></div>
  <div class="card"><div class="label">Platform Commission</div><div class="value">₹{{printf "%.0f" .Revenue.PlatformCommission}}</div></div>
  <div class="card"><div class="label">Technician Payouts</div><div class="value">₹{{printf "%.0f" .Revenue.TechnicianPayouts}}</div></div>
  <div class="card"><div class="label">Paid Bookings</div><div class="value">{{.Revenue.PaidBookingsCount}}</div></div>
  <div class="card"><div class="label">Refunded</div><div class="value">₹{{printf "%.0f" .Revenue.RefundedAmount}}</div></div>
</div>

<h2>Daily Revenue</h2>
<table><tr><th>Date</th><th>Revenue</th></tr>{{range .DailyRevenue}}<tr><td>{{.Date}}</td><td>₹{{printf "%.2f" .Value}}</td></tr>{{end}}</table>

<h2>Daily Bookings</h2>
<table><tr><th>Date</th><th>Bookings</th></tr>{{range .DailyBookings}}<tr><td>{{.Date}}</td><td>{{printf "%.0f" .Value}}</td></tr>{{end}}</table>

<h2>Daily Signups</h2>
<table><tr><th>Date</th><th>Signups</th></tr>{{range .DailySignups}}<tr><td>{{.Date}}</td><td>{{printf "%.0f" .Value}}</td></tr>{{end}}</table>`

	renderPage(c, "Analytics & Reports", "analytics", content, struct {
		From, To      string
		Revenue       interface{}
		DailyRevenue  interface{}
		DailyBookings interface{}
		DailySignups  interface{}
	}{From: from, To: to, Revenue: revenue, DailyRevenue: dailyRevenue, DailyBookings: dailyBookings, DailySignups: dailySignups})
}

// handleAnalyticsExport streams the same daily-revenue report as CSV (daily,
// weekly, or monthly reports are all just this date range, from/to picked
// accordingly by the caller).
func (d *Deps) handleAnalyticsExport(c *gin.Context) {
	from, to := dateRange(c)
	rows, err := d.Analytics.DailyRevenue(c.Request.Context(), from, to)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="revenue_%s_to_%s.csv"`, from, to))
	c.String(http.StatusOK, "date,revenue\n%s", dailyMetricsCSV(rows))
}

func dailyMetricsCSV(rows []models.DailyMetric) string {
	var b strings.Builder
	for _, r := range rows {
		fmt.Fprintf(&b, "%s,%.2f\n", r.Date, r.Value)
	}
	return b.String()
}
