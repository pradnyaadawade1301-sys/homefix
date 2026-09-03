package admin

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handleDisputesList(c *gin.Context) {
	status := c.Query("status")
	disputes, err := d.Dispute.ListAll(c.Request.Context(), status)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<div class="filters">
  <a href="/admin/disputes" class="{{if eq .Status ""}}active{{end}}">All</a>
  <a href="/admin/disputes?status=open" class="{{if eq .Status "open"}}active{{end}}">Open</a>
  <a href="/admin/disputes?status=under_review" class="{{if eq .Status "under_review"}}active{{end}}">Under Review</a>
</div>
<table>
<tr><th>Raised By</th><th>Subject</th><th>Reason</th><th>Status</th><th>Date</th><th>Action</th></tr>
{{range .Disputes}}
<tr>
  <td>{{.RaisedByName}}</td>
  <td>{{if .BookingID}}Booking {{derefS .BookingID}}{{else}}Consultation {{derefS .ConsultationID}}{{end}}</td>
  <td>{{.Reason}}</td>
  <td><span class="badge badge-{{.Status}}">{{.Status}}</span></td>
  <td>{{.CreatedAt.Format "2006-01-02"}}</td>
  <td>
    {{if eq .Status "open"}}
    <form class="inline" method="post" action="/admin/disputes/{{.ID}}/review">
      <button class="btn btn-sm" type="submit">Start Review</button>
    </form>
    {{end}}
    {{if or (eq .Status "open") (eq .Status "under_review")}}
    <form class="inline" method="post" action="/admin/disputes/{{.ID}}/resolve">
      <select name="status" style="width:auto;display:inline-block">
        <option value="resolved_refund">Refund</option>
        <option value="resolved_partial">Partial refund</option>
        <option value="resolved_rejected">Reject</option>
      </select>
      <input type="number" name="refund_amount" placeholder="Amount (if refund)" step="0.01" style="width:120px;display:inline-block">
      <input type="text" name="admin_notes" placeholder="Notes" style="width:140px;display:inline-block">
      <button class="btn btn-sm btn-primary" type="submit" onclick="return confirm('Resolve this dispute?')">Resolve</button>
    </form>
    {{end}}
  </td>
</tr>
{{end}}
</table>`
	renderPage(c, "Dispute Resolution", "disputes", content, struct {
		Disputes interface{}
		Status   string
	}{Disputes: disputes, Status: status})
}

func (d *Deps) handleDisputeReview(c *gin.Context) {
	id := c.Param("id")
	if err := d.Dispute.MarkUnderReview(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	d.audit(c, "dispute.review", "dispute", id, "")
	c.Redirect(http.StatusFound, "/admin/disputes")
}

func (d *Deps) handleDisputeResolve(c *gin.Context) {
	id := c.Param("id")
	status := c.PostForm("status")
	notes := c.PostForm("admin_notes")

	var refundAmount *float64
	if raw := c.PostForm("refund_amount"); raw != "" {
		if v, err := strconv.ParseFloat(raw, 64); err == nil {
			refundAmount = &v
		}
	}

	adminID := d.currentAdminID(c)
	if _, err := d.Dispute.Resolve(c.Request.Context(), id, status, notes, adminID, refundAmount); err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "dispute.resolve", "dispute", id, status)
	c.Redirect(http.StatusFound, "/admin/disputes")
}