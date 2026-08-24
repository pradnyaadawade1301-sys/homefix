package admin

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"homefix-backend/internal/models"
)

func (d *Deps) handleInventoryList(c *gin.Context) {
	parts, err := d.Inventory.ListParts(c.Request.Context(), "")
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	suppliers, err := d.Inventory.ListSuppliers(c.Request.Context())
	if err != nil {
		c.String(http.StatusInternalServerError, "%v", err)
		return
	}
	categories, _ := d.Category.List(c.Request.Context())

	const content = `
<h2>Spare Parts Catalog</h2>
<table>
<tr><th>Name</th><th>SKU</th><th>Category</th><th>Price</th><th>Stock</th><th>Reorder Level</th><th>Status</th><th>Restock</th></tr>
{{range .Parts}}
<tr {{if le .StockQuantity .ReorderLevel}}style="background:#fffbeb"{{end}}>
  <td>{{.Name}}</td><td>{{derefS .SKU}}</td><td>{{derefS .CategoryID}}</td>
  <td>₹{{printf "%.2f" .UnitPrice}}</td><td>{{.StockQuantity}}</td><td>{{.ReorderLevel}}</td>
  <td>{{if .IsActive}}<span class="badge badge-active">Active</span>{{else}}<span class="badge badge-rejected">Inactive</span>{{end}}</td>
  <td>
    <form class="inline" method="post" action="/admin/inventory/parts/{{.ID}}/restock">
      <input type="number" name="quantity" placeholder="Qty" min="1" style="width:70px;display:inline-block" required>
      <button class="btn btn-sm btn-primary" type="submit">Restock</button>
    </form>
  </td>
</tr>
{{end}}
</table>

<h2 id="low-stock">Add Spare Part</h2>
<form method="post" action="/admin/inventory/parts" style="max-width:420px">
  <div class="field"><label>Name</label><input type="text" name="name" required></div>
  <div class="field"><label>SKU</label><input type="text" name="sku"></div>
  <div class="field"><label>Category</label><select name="category_id">
    <option value="">—</option>
    {{range .Categories}}<option value="{{.ID}}">{{.Name}}</option>{{end}}
  </select></div>
  <div class="field"><label>Unit Price (₹)</label><input type="number" name="unit_price" step="0.01" required></div>
  <div class="field"><label>Initial Stock</label><input type="number" name="stock_quantity" value="0"></div>
  <div class="field"><label>Reorder Level</label><input type="number" name="reorder_level" value="5"></div>
  <button class="btn btn-primary" type="submit">Add Part</button>
</form>

<h2>Suppliers</h2>
<table>
<tr><th>Name</th><th>Contact</th><th>Phone</th><th>Email</th><th>Status</th></tr>
{{range .Suppliers}}
<tr><td>{{.Name}}</td><td>{{.ContactPerson}}</td><td>{{.Phone}}</td><td>{{.Email}}</td>
<td>{{if .IsActive}}<span class="badge badge-active">Active</span>{{else}}<span class="badge badge-rejected">Inactive</span>{{end}}</td></tr>
{{end}}
</table>
<form method="post" action="/admin/inventory/suppliers" style="max-width:420px;margin-top:10px">
  <div class="field"><label>Name</label><input type="text" name="name" required></div>
  <div class="field"><label>Contact person</label><input type="text" name="contact_person"></div>
  <div class="field"><label>Phone</label><input type="text" name="phone"></div>
  <div class="field"><label>Email</label><input type="text" name="email"></div>
  <button class="btn btn-primary" type="submit">Add Supplier</button>
</form>`
	renderPage(c, "Inventory", "inventory", content, struct {
		Parts      interface{}
		Suppliers  interface{}
		Categories interface{}
	}{Parts: parts, Suppliers: suppliers, Categories: categories})
}

func (d *Deps) handleCreateSparePart(c *gin.Context) {
	unitPrice, _ := strconv.ParseFloat(c.PostForm("unit_price"), 64)
	stockQty, _ := strconv.Atoi(c.PostForm("stock_quantity"))
	reorderLevel, _ := strconv.Atoi(c.PostForm("reorder_level"))

	p := &models.SparePart{
		Name:          c.PostForm("name"),
		UnitPrice:     unitPrice,
		StockQuantity: stockQty,
		ReorderLevel:  reorderLevel,
	}
	if sku := c.PostForm("sku"); sku != "" {
		p.SKU = &sku
	}
	if catID := c.PostForm("category_id"); catID != "" {
		p.CategoryID = &catID
	}

	created, err := d.Inventory.CreatePart(c.Request.Context(), p)
	if err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "inventory.create_part", "spare_part", created.ID, p.Name)
	c.Redirect(http.StatusFound, "/admin/inventory")
}

func (d *Deps) handleRestockPart(c *gin.Context) {
	id := c.Param("id")
	qty, _ := strconv.Atoi(c.PostForm("quantity"))
	if qty <= 0 {
		c.Redirect(http.StatusFound, "/admin/inventory")
		return
	}
	adminID := d.currentAdminID(c)
	note := "Manual restock via admin panel"
	if _, err := d.Inventory.AdjustStock(c.Request.Context(), id, "restock", qty, nil, &note, &adminID); err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "inventory.restock", "spare_part", id, note)
	c.Redirect(http.StatusFound, "/admin/inventory")
}

func (d *Deps) handleCreateSupplier(c *gin.Context) {
	s := &models.Supplier{
		Name:          c.PostForm("name"),
		ContactPerson: c.PostForm("contact_person"),
		Phone:         c.PostForm("phone"),
		Email:         c.PostForm("email"),
	}
	created, err := d.Inventory.CreateSupplier(c.Request.Context(), s)
	if err != nil {
		c.String(http.StatusBadRequest, "%v", err)
		return
	}
	d.audit(c, "inventory.create_supplier", "supplier", created.ID, s.Name)
	c.Redirect(http.StatusFound, "/admin/inventory")
}
