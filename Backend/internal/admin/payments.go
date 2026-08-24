package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handlePaymentsList(c *gin.Context) {
	status := c.Query("status")
	payments, err := d.Admin.ListPayments(c.Request.Context(), status)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<div class="filters">
  <a href="/admin/payments" class="{{if eq .Status ""}}active{{end}}">All</a>
  <a href="/admin/payments?status=created" class="{{if eq .Status "created"}}active{{end}}">Pending</a>
  <a href="/admin/payments?status=paid" class="{{if eq .Status "paid"}}active{{end}}">Paid</a>
  <a href="/admin/payments?status=failed" class="{{if eq .Status "failed"}}active{{end}}">Failed</a>
  <a href="/admin/payments?status=refunded" class="{{if eq .Status "refunded"}}active{{end}}">Refunded</a>
</div>
<table>
<tr><th>Ref</th><th>Amount</th><th>Status</th><th>UPI Status</th><th>Verified</th><th>Commission</th><th>Technician Earning</th><th>Invoice</th><th>Date</th><th></th></tr>
{{range .Payments}}
<tr>
  <td>{{.TransactionRef}}</td>
  <td>₹{{printf "%.2f" .Amount}}</td>
  <td><span class="badge badge-{{.Status}}">{{.Status}}</span></td>
  <td>{{if .UpiStatus}}{{derefS .UpiStatus}}{{else}}—{{end}}</td>
  <td>{{if .Verified}}Yes{{else}}No{{end}}</td>
  <td>{{if .PlatformCommission}}₹{{printf "%.2f" (derefF .PlatformCommission)}}{{else}}—{{end}}</td>
  <td>{{if .TechnicianEarning}}₹{{printf "%.2f" (derefF .TechnicianEarning)}}{{else}}—{{end}}</td>
  <td>{{if .InvoiceNumber}}{{derefS .InvoiceNumber}}{{end}}</td>
  <td>{{.CreatedAt.Format "2006-01-02"}}</td>
  <td>
    {{if eq .Status "paid"}}
    <form class="inline" method="post" action="/admin/payments/{{.ID}}/refund" onsubmit="return confirm('Refund this payment?')">
      <button class="btn btn-sm btn-danger" type="submit">Refund</button>
    </form>
    {{end}}
  </td>
</tr>
{{end}}
</table>`
	renderPage(c, "Payment Monitoring", "payments", content, struct {
		Payments interface{}
		Status   string
	}{Payments: payments, Status: status})
}

func (d *Deps) handleRefundPayment(c *gin.Context) {
	id := c.Param("id")
	if _, err := d.Upi.Refund(c.Request.Context(), id); err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "payment.refund", "payment", id, "")
	c.Redirect(http.StatusFound, "/admin/payments")
}
