package admin

import (
	"html/template"
	"net/http"

	"github.com/gin-gonic/gin"
)

// All admin HTML is rendered server-side with html/template, which auto-escapes
// every {{.Field}} interpolation — nothing here builds HTML via raw string
// concatenation, so user-supplied data (dispute reasons, CMS content, names) can
// never inject a script tag into the page (XSS protection).
const baseCSS = `
:root{--bg:#f4f6f9;--card:#fff;--text:#1a1f36;--muted:#6b7280;--border:#e5e7eb;--primary:#4f46e5;--danger:#dc2626;--success:#059669;--warn:#d97706}
*{box-sizing:border-box}
body{margin:0;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:var(--bg);color:var(--text)}
a{color:var(--primary);text-decoration:none}
.nav{background:#111827;color:#fff;padding:0 20px;display:flex;align-items:center;height:56px;gap:4px;overflow-x:auto}
.nav .brand{font-weight:700;margin-right:24px;white-space:nowrap}
.nav a{color:#d1d5db;padding:8px 12px;border-radius:6px;font-size:14px;white-space:nowrap}
.nav a:hover,.nav a.active{background:#1f2937;color:#fff}
.nav .spacer{flex:1}
.wrap{padding:24px;max-width:1300px;margin:0 auto}
h1{font-size:22px;margin:0 0 16px}
h2{font-size:16px;margin:24px 0 10px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin-bottom:20px}
.card{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:16px}
.card .label{font-size:12px;color:var(--muted);margin-bottom:6px}
.card .value{font-size:24px;font-weight:700}
table{width:100%;border-collapse:collapse;background:var(--card);border:1px solid var(--border);border-radius:8px;overflow:hidden}
th,td{padding:10px 12px;border-bottom:1px solid var(--border);text-align:left;font-size:13.5px;vertical-align:top}
th{background:#fafafa;color:var(--muted);font-weight:600}
tr:last-child td{border-bottom:none}
.badge{display:inline-block;padding:2px 8px;border-radius:99px;font-size:11.5px;font-weight:600}
.badge-pending{background:#fef3c7;color:#92400e}
.badge-approved,.badge-paid,.badge-active,.badge-resolved_refund,.badge-completed{background:#d1fae5;color:#065f46}
.badge-rejected,.badge-failed,.badge-cancelled{background:#fee2e2;color:#991b1b}
.badge-open,.badge-under_review{background:#fee2e2;color:#991b1b}
.btn{display:inline-block;padding:6px 14px;border-radius:6px;border:1px solid var(--border);background:#fff;cursor:pointer;font-size:13px;color:var(--text)}
.btn-primary{background:var(--primary);color:#fff;border-color:var(--primary)}
.btn-danger{background:var(--danger);color:#fff;border-color:var(--danger)}
.btn-sm{padding:4px 10px;font-size:12px}
form.inline{display:inline}
input[type=text],input[type=password],input[type=number],textarea,select{width:100%;padding:8px 10px;border:1px solid var(--border);border-radius:6px;font-size:14px;font-family:inherit}
.field{margin-bottom:12px}
.field label{display:block;font-size:12.5px;color:var(--muted);margin-bottom:4px}
.error{background:#fee2e2;color:#991b1b;padding:10px 14px;border-radius:8px;margin-bottom:14px;font-size:13.5px}
.muted{color:var(--muted)}
.login-wrap{max-width:360px;margin:80px auto;background:#fff;border:1px solid var(--border);border-radius:12px;padding:32px}
.filters{margin-bottom:14px;font-size:13px}
.filters a{margin-right:10px;padding:4px 10px;border-radius:6px}
.filters a.active{background:var(--primary);color:#fff}
`

const navHTML = `
<div class="nav">
  <div class="brand">HomeFix Admin</div>
  <a href="/admin" class="{{if eq .Active "dashboard"}}active{{end}}">Dashboard</a>
  <a href="/admin/users" class="{{if eq .Active "users"}}active{{end}}">Users</a>
  <a href="/admin/technicians" class="{{if eq .Active "technicians"}}active{{end}}">Technicians</a>
  <a href="/admin/bookings" class="{{if eq .Active "bookings"}}active{{end}}">Bookings</a>
  <a href="/admin/payments" class="{{if eq .Active "payments"}}active{{end}}">Payments</a>
  <a href="/admin/disputes" class="{{if eq .Active "disputes"}}active{{end}}">Disputes</a>
  <a href="/admin/inventory" class="{{if eq .Active "inventory"}}active{{end}}">Inventory</a>
  <a href="/admin/cms" class="{{if eq .Active "cms"}}active{{end}}">CMS</a>
  <a href="/admin/analytics" class="{{if eq .Active "analytics"}}active{{end}}">Analytics</a>
  <a href="/admin/audit-logs" class="{{if eq .Active "audit"}}active{{end}}">Audit Logs</a>
  <div class="spacer"></div>
  <form method="post" action="/admin/logout" class="inline"><button class="btn btn-sm" type="submit">Log out</button></form>
</div>
`

// pageShell's {{.Nav}} and {{.Content}} are already-rendered template.HTML (see
// renderPage) — the nav must NOT be embedded here as literal template source,
// since that would make its {{if eq .Active ...}} actions part of THIS template,
// evaluated against data that has no .Active field at all, and fail mid-render.
const pageShell = `<!doctype html>
<html><head><meta charset="utf-8"><title>{{.Title}} · HomeFix Admin</title>
<style>` + baseCSS + `</style></head>
<body>{{.Nav}}<div class="wrap"><h1>{{.Title}}</h1>{{.Content}}</div></body></html>`

var shellTpl = template.Must(template.New("shell").Parse(pageShell))
var navTpl = template.Must(template.New("nav").Parse(navHTML))

// funcMap adds helpers content templates need beyond stock html/template:
// dereferencing the *float64/*int fields BookingDetail etc. use for "may not be
// set yet" columns, which fmt can't format directly.
var funcMap = template.FuncMap{
	"derefF": func(f *float64) float64 {
		if f == nil {
			return 0
		}
		return *f
	},
	"derefI": func(i *int) int {
		if i == nil {
			return 0
		}
		return *i
	},
	"derefS": func(s *string) string {
		if s == nil {
			return ""
		}
		return *s
	},
}

// renderPage renders `contentTpl` (a template fragment referencing `data`) inside
// the shared shell/nav. Kept as a two-pass render (content -> string -> shell) so
// each page's template source stays simple and self-contained.
func renderPage(c *gin.Context, title, active, contentTpl string, data interface{}) {
	tpl, err := template.New("content").Funcs(funcMap).Parse(contentTpl)
	if err != nil {
		c.String(http.StatusInternalServerError, "template error: %v", err)
		return
	}
	var bodyBuf writerBuf
	if err := tpl.Execute(&bodyBuf, data); err != nil {
		c.String(http.StatusInternalServerError, "render error: %v", err)
		return
	}

	var navBuf writerBuf
	if err := navTpl.Execute(&navBuf, map[string]string{"Active": active}); err != nil {
		c.String(http.StatusInternalServerError, "nav render error: %v", err)
		return
	}

	c.Header("Content-Type", "text/html; charset=utf-8")
	c.Header("X-Content-Type-Options", "nosniff")
	c.Header("X-Frame-Options", "DENY")
	c.Status(http.StatusOK)

	if err := shellTpl.Execute(c.Writer, struct {
		Title   string
		Nav     template.HTML
		Content template.HTML
	}{
		Title:   title,
		Nav:     template.HTML(navBuf.String()),
		Content: template.HTML(bodyBuf.String()),
	}); err != nil {
		// Status/headers are already sent at this point — log-equivalent via panic
		// recovery elsewhere isn't set up here, so just note it in the response
		// stream itself (best effort; the page is likely already partially sent).
		_, _ = c.Writer.Write([]byte("<!-- shell render error: " + template.HTMLEscapeString(err.Error()) + " -->"))
	}
}

func renderLogin(c *gin.Context, errMsg string) {
	const content = `
<div class="login-wrap">
  <h1 style="text-align:center">HomeFix Admin</h1>
  {{if .Error}}<div class="error">{{.Error}}</div>{{end}}
  <form method="post" action="/admin/login">
    <div class="field"><label>Email or phone</label><input type="text" name="identifier" required autofocus></div>
    <div class="field"><label>Password</label><input type="password" name="password" required></div>
    <button class="btn btn-primary" type="submit" style="width:100%">Sign in</button>
  </form>
</div>`
	tpl := template.Must(template.New("login").Parse(`<!doctype html><html><head><meta charset="utf-8"><title>Admin Login · HomeFix</title><style>` + baseCSS + `</style></head><body>` + content + `</body></html>`))
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.Header("X-Frame-Options", "DENY")
	_ = tpl.Execute(c.Writer, struct{ Error string }{Error: errMsg})
}

// writerBuf is a tiny io.Writer-backed string builder (avoids importing bytes
// just for this).
type writerBuf struct{ s string }

func (w *writerBuf) Write(p []byte) (int, error) {
	w.s += string(p)
	return len(p), nil
}
func (w *writerBuf) String() string { return w.s }