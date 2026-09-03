package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handleDashboard(c *gin.Context) {
	stats, err := d.Analytics.Dashboard(c.Request.Context())
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<div class="cards">
  <div class="card"><div class="label">Total Customers</div><div class="value">{{.S.TotalCustomers}}</div></div>
  <div class="card"><div class="label">Total Technicians</div><div class="value">{{.S.TotalTechnicians}}</div></div>
  <div class="card"><div class="label">Pending KYC</div><div class="value">{{.S.PendingTechnicianKyc}}</div></div>
  <div class="card"><div class="label">Total Bookings</div><div class="value">{{.S.TotalBookings}}</div></div>
  <div class="card"><div class="label">Bookings Today</div><div class="value">{{.S.BookingsToday}}</div></div>
  <div class="card"><div class="label">Open Disputes</div><div class="value">{{.S.OpenDisputes}}</div></div>
  <div class="card"><div class="label">Total Revenue</div><div class="value">₹{{printf "%.0f" .S.TotalRevenue}}</div></div>
  <div class="card"><div class="label">Revenue Today</div><div class="value">₹{{printf "%.0f" .S.RevenueToday}}</div></div>
  <div class="card"><div class="label">AI Sessions</div><div class="value">{{.S.AiSessionsTotal}}</div></div>
  <div class="card"><div class="label">Consultation → Booking</div><div class="value">{{printf "%.1f" .S.ConsultationToBookingPct}}%</div></div>
</div>
<p class="muted">Quick links: <a href="/admin/technicians?status=pending">Pending technician approvals</a> ·
<a href="/admin/disputes?status=open">Open disputes</a> ·
<a href="/admin/inventory#low-stock">Low stock parts</a></p>
`
	renderPage(c, "Dashboard", "dashboard", content, struct{ S interface{} }{S: stats})
}