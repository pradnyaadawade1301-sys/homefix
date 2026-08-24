package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handleAuditLogs(c *gin.Context) {
	logs, err := d.Audit.List(c.Request.Context(), 200)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<table>
<tr><th>When</th><th>Admin</th><th>Action</th><th>Entity</th><th>Details</th><th>IP</th></tr>
{{range .Logs}}
<tr>
  <td>{{.CreatedAt.Format "2006-01-02 15:04:05"}}</td>
  <td>{{.AdminName}}</td>
  <td>{{.Action}}</td>
  <td>{{.EntityType}} {{.EntityID}}</td>
  <td>{{.Details}}</td>
  <td>{{.IPAddress}}</td>
</tr>
{{end}}
</table>`
	renderPage(c, "Audit Logs", "audit", content, struct{ Logs interface{} }{Logs: logs})
}
