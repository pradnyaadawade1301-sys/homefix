package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/models"
)

var cmsPageKeys = []struct{ Key, Title string }{
	{"about_us", "About Us"},
	{"privacy_policy", "Privacy Policy"},
	{"terms_conditions", "Terms & Conditions"},
	{"help_center", "Help Center"},
}

func (d *Deps) handleCmsList(c *gin.Context) {
	ctx := c.Request.Context()

	pages := map[string]*models.CmsPage{}
	for _, k := range cmsPageKeys {
		p, _ := d.Cms.GetPage(ctx, k.Key)
		pages[k.Key] = p
	}
	faqs, _ := d.Cms.ListFaqs(ctx, false)
	announcements, _ := d.Cms.ListAnnouncements(ctx, false)
	banners, _ := d.Cms.ListBanners(ctx, false)

	const content = `
<h2>Pages</h2>
{{range .PageKeys}}
<form method="post" action="/admin/cms/pages/{{.Key}}" style="margin-bottom:16px;max-width:600px">
  <div class="field"><label>{{.Title}}</label>
  <textarea name="content" rows="4">{{index $.PageContent .Key}}</textarea></div>
  <button class="btn btn-sm btn-primary" type="submit">Save {{.Title}}</button>
</form>
{{end}}

<h2>FAQs</h2>
<table><tr><th>Question</th><th>Answer</th><th>Status</th><th></th></tr>
{{range .Faqs}}
<tr><td>{{.Question}}</td><td>{{.Answer}}</td>
<td>{{if .IsActive}}<span class="badge badge-active">Active</span>{{else}}<span class="badge badge-rejected">Hidden</span>{{end}}</td>
<td>
  <form class="inline" method="post" action="/admin/cms/faqs/{{.ID}}/toggle"><button class="btn btn-sm" type="submit">Toggle</button></form>
  <form class="inline" method="post" action="/admin/cms/faqs/{{.ID}}/delete" onsubmit="return confirm('Delete this FAQ?')"><button class="btn btn-sm btn-danger" type="submit">Delete</button></form>
</td></tr>
{{end}}
</table>
<form method="post" action="/admin/cms/faqs" style="max-width:500px;margin-top:10px">
  <div class="field"><label>Question</label><input type="text" name="question" required></div>
  <div class="field"><label>Answer</label><textarea name="answer" rows="2" required></textarea></div>
  <button class="btn btn-primary" type="submit">Add FAQ</button>
</form>

<h2>Announcements</h2>
<table><tr><th>Title</th><th>Body</th><th>Status</th><th></th></tr>
{{range .Announcements}}
<tr><td>{{.Title}}</td><td>{{.Body}}</td>
<td>{{if .IsActive}}<span class="badge badge-active">Active</span>{{else}}<span class="badge badge-rejected">Hidden</span>{{end}}</td>
<td><form class="inline" method="post" action="/admin/cms/announcements/{{.ID}}/toggle"><button class="btn btn-sm" type="submit">Toggle</button></form></td></tr>
{{end}}
</table>
<form method="post" action="/admin/cms/announcements" style="max-width:500px;margin-top:10px">
  <div class="field"><label>Title</label><input type="text" name="title" required></div>
  <div class="field"><label>Body</label><textarea name="body" rows="2" required></textarea></div>
  <button class="btn btn-primary" type="submit">Add Announcement</button>
</form>

<h2>Promotional Banners</h2>
<table><tr><th>Title</th><th>Image URL</th><th>Link</th><th>Status</th><th></th></tr>
{{range .Banners}}
<tr><td>{{.Title}}</td><td>{{.ImageURL}}</td><td>{{.LinkURL}}</td>
<td>{{if .IsActive}}<span class="badge badge-active">Active</span>{{else}}<span class="badge badge-rejected">Hidden</span>{{end}}</td>
<td><form class="inline" method="post" action="/admin/cms/banners/{{.ID}}/toggle"><button class="btn btn-sm" type="submit">Toggle</button></form></td></tr>
{{end}}
</table>
<form method="post" action="/admin/cms/banners" style="max-width:500px;margin-top:10px">
  <div class="field"><label>Title</label><input type="text" name="title"></div>
  <div class="field"><label>Image URL</label><input type="text" name="image_url" required></div>
  <div class="field"><label>Link URL</label><input type="text" name="link_url"></div>
  <button class="btn btn-primary" type="submit">Add Banner</button>
</form>`

	pageContent := map[string]string{}
	for k, p := range pages {
		if p != nil {
			pageContent[k] = p.Content
		}
	}

	renderPage(c, "CMS", "cms", content, struct {
		PageKeys      interface{}
		PageContent   map[string]string
		Faqs          interface{}
		Announcements interface{}
		Banners       interface{}
	}{PageKeys: cmsPageKeys, PageContent: pageContent, Faqs: faqs, Announcements: announcements, Banners: banners})
}

func (d *Deps) handleSaveCmsPage(c *gin.Context) {
	key := c.Param("key")
	content := c.PostForm("content")
	title := key
	for _, k := range cmsPageKeys {
		if k.Key == key {
			title = k.Title
		}
	}
	if _, err := d.Cms.SavePage(c.Request.Context(), key, title, content, d.currentAdminID(c)); err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "cms.save_page", "cms_page", key, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleCreateFaq(c *gin.Context) {
	f := &models.CmsFaq{Question: c.PostForm("question"), Answer: c.PostForm("answer")}
	created, err := d.Cms.CreateFaq(c.Request.Context(), f)
	if err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "cms.create_faq", "cms_faq", created.ID, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleToggleFaq(c *gin.Context) {
	id := c.Param("id")
	faqs, _ := d.Cms.ListFaqs(c.Request.Context(), false)
	active := false
	for _, f := range faqs {
		if f.ID == id {
			active = f.IsActive
		}
	}
	_ = d.Cms.SetFaqActive(c.Request.Context(), id, !active)
	d.audit(c, "cms.toggle_faq", "cms_faq", id, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleDeleteFaq(c *gin.Context) {
	id := c.Param("id")
	_ = d.Cms.DeleteFaq(c.Request.Context(), id)
	d.audit(c, "cms.delete_faq", "cms_faq", id, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleCreateAnnouncement(c *gin.Context) {
	a := &models.CmsAnnouncement{Title: c.PostForm("title"), Body: c.PostForm("body")}
	created, err := d.Cms.CreateAnnouncement(c.Request.Context(), a)
	if err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "cms.create_announcement", "cms_announcement", created.ID, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleToggleAnnouncement(c *gin.Context) {
	id := c.Param("id")
	list, _ := d.Cms.ListAnnouncements(c.Request.Context(), false)
	active := false
	for _, a := range list {
		if a.ID == id {
			active = a.IsActive
		}
	}
	_ = d.Cms.SetAnnouncementActive(c.Request.Context(), id, !active)
	d.audit(c, "cms.toggle_announcement", "cms_announcement", id, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleCreateBanner(c *gin.Context) {
	b := &models.CmsBanner{Title: c.PostForm("title"), ImageURL: c.PostForm("image_url"), LinkURL: c.PostForm("link_url")}
	created, err := d.Cms.CreateBanner(c.Request.Context(), b)
	if err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "cms.create_banner", "cms_banner", created.ID, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}

func (d *Deps) handleToggleBanner(c *gin.Context) {
	id := c.Param("id")
	list, _ := d.Cms.ListBanners(c.Request.Context(), false)
	active := false
	for _, b := range list {
		if b.ID == id {
			active = b.IsActive
		}
	}
	_ = d.Cms.SetBannerActive(c.Request.Context(), id, !active)
	d.audit(c, "cms.toggle_banner", "cms_banner", id, "")
	c.Redirect(http.StatusFound, "/admin/cms")
}