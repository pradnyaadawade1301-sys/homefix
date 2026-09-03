package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handleTechniciansList(c *gin.Context) {
	status := c.Query("status")
	techs, err := d.Admin.ListTechniciansByStatus(c.Request.Context(), status)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<div class="filters">
  <a href="/admin/technicians" class="{{if eq .Status ""}}active{{end}}">All</a>
  <a href="/admin/technicians?status=pending" class="{{if eq .Status "pending"}}active{{end}}">Pending</a>
  <a href="/admin/technicians?status=approved" class="{{if eq .Status "approved"}}active{{end}}">Approved</a>
  <a href="/admin/technicians?status=rejected" class="{{if eq .Status "rejected"}}active{{end}}">Rejected</a>
</div>
<table>
<tr><th>Name</th><th>Phone</th><th>Category</th><th>Exp.</th><th>Rating</th><th>Status</th><th>Documents</th><th>Action</th></tr>
{{range .Techs}}
<tr>
  <td>{{.Name}}</td><td>{{.Phone}}</td><td>{{.CategoryName}}</td><td>{{.ExperienceYears}}y</td>
  <td>{{printf "%.1f" .RatingAvg}} ({{.RatingCount}})</td>
  <td><span class="badge badge-{{.ApprovalStatus}}">{{.ApprovalStatus}}</span>{{if .RejectionReason}}<div class="muted">{{.RejectionReason}}</div>{{end}}</td>
  <td>
    {{if .GovernmentIDURL}}<a href="{{.GovernmentIDURL}}" target="_blank" rel="noopener">ID</a>{{end}}
    {{if .ProfilePhotoURL}} · <a href="{{.ProfilePhotoURL}}" target="_blank" rel="noopener">Photo</a>{{end}}
  </td>
  <td>
    {{if eq .ApprovalStatus "pending"}}
    <form class="inline" method="post" action="/admin/technicians/{{.ID}}/approve">
      <button class="btn btn-sm btn-primary" type="submit">Approve</button>
    </form>
    <form class="inline" method="post" action="/admin/technicians/{{.ID}}/reject" onsubmit="return this.reason.value.trim().length>0">
      <input type="text" name="reason" placeholder="Rejection reason" style="width:140px;display:inline-block">
      <button class="btn btn-sm btn-danger" type="submit">Reject</button>
    </form>
    {{else}}<span class="muted">—</span>{{end}}
  </td>
</tr>
{{end}}
</table>`
	renderPage(c, "Technician Approval", "technicians", content, struct {
		Techs  interface{}
		Status string
	}{Techs: techs, Status: status})
}

func (d *Deps) handleApproveTechnician(c *gin.Context) {
	id := c.Param("id")
	if err := d.Admin.ApproveTechnician(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	d.audit(c, "technician.approve", "technician", id, "")
	c.Redirect(http.StatusFound, "/admin/technicians?status=pending")
}

func (d *Deps) handleRejectTechnician(c *gin.Context) {
	id := c.Param("id")
	reason := c.PostForm("reason")
	if err := d.Admin.RejectTechnician(c.Request.Context(), id, reason); err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	d.audit(c, "technician.reject", "technician", id, reason)
	c.Redirect(http.StatusFound, "/admin/technicians?status=pending")
}