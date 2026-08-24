package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (d *Deps) handleUsersList(c *gin.Context) {
	role := c.Query("role")
	users, err := d.Admin.ListUsers(c.Request.Context(), role)
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}

	const content = `
<div class="filters">
  <a href="/admin/users" class="{{if eq .Role ""}}active{{end}}">All</a>
  <a href="/admin/users?role=customer" class="{{if eq .Role "customer"}}active{{end}}">Customers</a>
  <a href="/admin/users?role=technician" class="{{if eq .Role "technician"}}active{{end}}">Technicians</a>
  <a href="/admin/users?role=admin" class="{{if eq .Role "admin"}}active{{end}}">Admins</a>
</div>
<table>
<tr><th>Name</th><th>Phone</th><th>Email</th><th>Role</th><th>Status</th><th>Joined</th><th></th></tr>
{{range .Users}}
<tr>
  <td>{{.Name}}</td><td>{{.Phone}}</td><td>{{derefS .Email}}</td><td>{{.Role}}</td>
  <td>{{if .IsActive}}<span class="badge badge-active">Active</span>{{else}}<span class="badge badge-rejected">Suspended</span>{{end}}</td>
  <td>{{.CreatedAt.Format "2006-01-02"}}</td>
  <td>
    <form class="inline" method="post" action="/admin/users/{{.ID}}/toggle-active">
      {{if .IsActive}}<button class="btn btn-sm btn-danger" type="submit">Suspend</button>
      {{else}}<button class="btn btn-sm btn-primary" type="submit">Reactivate</button>{{end}}
    </form>
  </td>
</tr>
{{end}}
</table>`
	renderPage(c, "User Management", "users", content, struct {
		Users interface{}
		Role  string
	}{Users: users, Role: role})
}

func (d *Deps) handleToggleUserActive(c *gin.Context) {
	userID := c.Param("id")
	users, err := d.Admin.ListUsers(c.Request.Context(), "")
	active := true
	if err == nil {
		for _, u := range users {
			if u.ID == userID {
				active = u.IsActive
				break
			}
		}
	}
	if err := d.Admin.SetUserActive(c.Request.Context(), userID, !active); err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	d.audit(c, "user.toggle_active", "user", userID, "")
	c.Redirect(http.StatusFound, "/admin/users")
}
