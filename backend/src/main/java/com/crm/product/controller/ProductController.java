package com.crm.product.controller;

import com.crm.auth.service.AuthService;
import com.crm.product.model.ProductForm;
import com.crm.product.service.CatalogService;
import com.crm.product.service.ProductService;
import com.crm.product.service.ProductCsvService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ProductController {
    private final ProductService products;
    private final CatalogService catalog;
    private final AuthService auth;
    private final ProductCsvService csv;
    private final com.crm.product.service.InventoryService inventory;

    public ProductController(ProductService products, CatalogService catalog, AuthService auth, ProductCsvService csv, com.crm.product.service.InventoryService inventory) {
        this.products = products;
        this.catalog = catalog;
        this.auth = auth;
        this.csv = csv;
        this.inventory = inventory;
    }

    @ModelAttribute("permissions")
    public List<String> permissions(@SessionAttribute(required = false) Long employeeId) {
        if (employeeId == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        return auth.current(employeeId).permissions();
    }

    @GetMapping("/inventory")
    public Object inventory(@ModelAttribute("permissions") List<String> p,
                            @RequestParam(defaultValue="") String keyword,@RequestParam(defaultValue="") String stock,
                            @RequestParam(defaultValue="1") int page,@RequestParam(defaultValue="200") int pageSize) {
        require(p,"product.view");
        if (page < 1 || pageSize < 1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        return inventory.list(keyword.trim(),stock,page,pageSize);
    }

    @GetMapping({"/products","/products/prices"})
    public Object list(@ModelAttribute("permissions") List<String> permissions,
                       @RequestParam(required=false) String keyword, @RequestParam(required=false) Long categoryId,
                       @RequestParam(required=false) String brand, @RequestParam(required=false) String status,
                       @RequestParam(required=false) String mode, @RequestParam(defaultValue="1") int page,
                       @RequestParam(defaultValue="20") int pageSize) {
        require(permissions,"product.view");
        if (page < 1 || pageSize < 1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        var rows = products.list(keyword,categoryId,brand,status,mode,permissions.contains("product.cost"));
        int from = (int)Math.min(rows.size(), (long)(page - 1) * pageSize);
        int to = (int)Math.min(rows.size(), (long)from + pageSize);
        return Map.of("rows",rows.subList(from,to),"total",rows.size(),"page",page,"pageSize",pageSize);
    }

    @GetMapping("/products/{id}")
    public Object detail(@ModelAttribute("permissions") List<String> p,@PathVariable long id) {
        require(p,"product.view");
        return products.detail(id,p.contains("product.cost"));
    }

    @PostMapping("/products")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String,Long> create(@ModelAttribute("permissions") List<String> p,@RequestBody ProductForm form) {
        require(p,"product.edit");
        return Map.of("id",products.save(null,form,p.contains("product.price"),p.contains("product.cost")));
    }

    @PutMapping("/products/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody ProductForm form) {
        require(p,"product.edit");
        products.save(id,form,p.contains("product.price"),p.contains("product.cost"));
    }

    @PatchMapping("/products/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void status(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody Map<String,String> form) {
        require(p,"product.edit");
        products.status(id,form.get("status"));
    }

    @PatchMapping("/products/{id}/stock")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void stock(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody Map<String,String> form) {
        require(p,"product.edit");
        products.stock(id,form.get("stock"));
    }

    @DeleteMapping("/products/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@ModelAttribute("permissions") List<String> p,@PathVariable long id) {
        require(p,"product.edit");
        products.delete(id);
    }

    @PutMapping("/products/{id}/prices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void price(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody ProductForm.Prices form) {
        require(p,"product.price");
        products.savePrice(id,form,p.contains("product.cost"));
    }

    @PostMapping("/products/prices/batch")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void batch(@ModelAttribute("permissions") List<String> p,@RequestBody Batch form) {
        require(p,"product.price");
        products.batch(form.ids(),form.kind(),form.mode(),form.value(),p.contains("product.cost"));
    }

    @GetMapping("/product-categories")
    public Object categories(@ModelAttribute("permissions") List<String> p) {
        require(p,"product.view");
        return catalog.categories();
    }

    @PostMapping("/product-categories")
    @ResponseStatus(HttpStatus.CREATED)
    public void createCategory(@ModelAttribute("permissions") List<String> p,@RequestBody CatalogService.Category form) {
        require(p,"product.edit");
        catalog.category(null,form);
    }

    @PutMapping("/product-categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateCategory(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody CatalogService.Category form) {
        require(p,"product.edit");
        catalog.category(id,form);
    }

    @DeleteMapping("/product-categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(@ModelAttribute("permissions") List<String> p,@PathVariable long id) {
        require(p,"product.edit");
        catalog.deleteCategory(id);
    }

    @GetMapping("/product-bundles")
    public Object bundles(@ModelAttribute("permissions") List<String> p) {
        require(p,"product.view");
        return catalog.bundles();
    }

    @PostMapping("/product-bundles")
    @ResponseStatus(HttpStatus.CREATED)
    public void createBundle(@ModelAttribute("permissions") List<String> p,@RequestBody CatalogService.Bundle form) {
        require(p,"product.edit");
        catalog.bundle(null,form);
    }

    @PutMapping("/product-bundles/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateBundle(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody CatalogService.Bundle form) {
        require(p,"product.edit");
        catalog.bundle(id,form);
    }

    @PatchMapping("/product-bundles/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void bundleStatus(@ModelAttribute("permissions") List<String> p,@PathVariable long id,@RequestBody Map<String,String> form) {
        require(p,"product.edit");
        catalog.bundleStatus(id,form.get("status"));
    }

    @GetMapping("/customer-prices")
    public Object agreements(@ModelAttribute("permissions") List<String> p) {
        require(p,"product.view");
        return catalog.customerPrices();
    }

    @PutMapping("/customer-prices/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void agreement(@ModelAttribute("permissions") List<String> p,@SessionAttribute Long employeeId,
                          @PathVariable long id,@RequestBody CatalogService.Agreement form) {
        require(p,"product.price");
        catalog.customerPrice(id,employeeId,form);
    }

    @PostMapping("/products/import")
    public Object upload(@ModelAttribute("permissions") List<String> p, @RequestParam MultipartFile file) throws IOException {
        require(p,"product.import");
        require(p,"product.edit");
        require(p,"product.price");
        return csv.upload(new String(file.getBytes(),StandardCharsets.UTF_8));
    }

    @GetMapping("/products/export")
    public ResponseEntity<String> export(@ModelAttribute("permissions") List<String> p,
            @RequestParam(required=false) String keyword, @RequestParam(required=false) Long categoryId,
            @RequestParam(required=false) String brand, @RequestParam(required=false) String status,
            @RequestParam(required=false) String mode) {
        require(p,"product.import");
        return ResponseEntity.ok().header("Content-Type","text/csv; charset=UTF-8")
                .header("Content-Disposition","attachment; filename=products.csv")
                .body(csv.export(keyword,categoryId,brand,status,mode));
    }

    @ExceptionHandler(ProductCsvService.ImportError.class)
    public Object importError(ProductCsvService.ImportError error) {
        return Map.of("created",0,"updated",0,"failed",1,
                "errors",List.of(Map.of("row",error.row,"message","Invalid CSV row; import rolled back")));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public void constraintViolation() {}

    private void require(List<String> permissions,String code) {
        if (!permissions.contains(code)) throw new ResponseStatusException(HttpStatus.FORBIDDEN);
    }

    public record Batch(List<Long> ids,String kind,String mode,BigDecimal value) {}
}

