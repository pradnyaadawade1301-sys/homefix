package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handleBookingsList(c *gin.Context) {
	status := c.Query("status")
	bookings, err := d.Admin.ListBookings(c.Request.Context(), status)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<div class="filters">
  <a href="/admin/bookings" class="{{if eq .Status ""}}active{{end}}">All</a>
  <a href="/admin/bookings?status=requested" class="{{if eq .Status "requested"}}active{{end}}">Requested</a>
  <a href="/admin/bookings?status=accepted" class="{{if eq .Status "accepted"}}active{{end}}">Accepted</a>
  <a href="/admin/bookings?status=in_progress" class="{{if eq .Status "in_progress"}}active{{end}}">In Progress</a>
  <a href="/admin/bookings?status=completed" class="{{if eq .Status "completed"}}active{{end}}">Completed</a>
  <a href="/admin/bookings?status=cancelled" class="{{if eq .Status "cancelled"}}active{{end}}">Cancelled</a>
</div>
<table>
<tr><th>Customer</th><th>Technician</th><th>Category</th><th>Status</th><th>Payment</th><th>Price</th><th>Created</th></tr>
{{range .Bookings}}
<tr>
  <td>{{.Customer.Name}}<div class="muted">{{.Customer.Phone}}</div></td>
  <td>{{if .Technician}}{{.Technician.Name}}{{else}}<span class="muted">Unassigned</span>{{end}}</td>
  <td>{{.CategoryName}}</td>
  <td><span class="badge badge-{{.Status}}">{{.Status}}</span></td>
  <td><span class="badge badge-{{.PaymentStatus}}">{{.PaymentStatus}}</span></td>
  <td>{{if .FinalPrice}}₹{{printf "%.0f" (derefF .FinalPrice)}}{{else if .EstimatedPrice}}~₹{{printf "%.0f" (derefF .EstimatedPrice)}}{{else}}—{{end}}</td>
  <td>{{.CreatedAt.Format "2006-01-02 15:04"}}</td>
</tr>
{{end}}
</table>`
	renderPage(c, "Booking Management", "bookings", content, struct {
		Bookings interface{}
		Status   string
	}{Bookings: bookings, Status: status})
}
