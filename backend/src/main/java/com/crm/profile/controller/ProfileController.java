package com.crm.profile.controller;

import com.crm.profile.model.LoginRecord;
import com.crm.profile.model.Profile;
import com.crm.profile.service.ProfileService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/profile")
public class ProfileController {
    private final ProfileService service;

    public ProfileController(ProfileService service) {
        this.service = service;
    }

    @GetMapping
    public Profile get(HttpServletRequest request) {
        return service.get(request.getSession(false));
    }

    @PutMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(HttpServletRequest request, @RequestBody Basic form) {
        service.update(request.getSession(false), form.name(), form.phone(), form.email());
    }

    @PostMapping("/avatar")
    public Map<String, String> avatar(HttpServletRequest request, @RequestBody Avatar form) {
        return Map.of("avatar", service.uploadAvatar(request.getSession(false), form.dataUrl()));
    }

    @PostMapping("/password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void password(HttpServletRequest request, @RequestBody Password form) {
        service.changePassword(request.getSession(false), form.oldPassword(), form.newPassword());
    }

    @GetMapping("/logins")
    public List<LoginRecord> logins(HttpServletRequest request) {
        return service.logins(request.getSession(false));
    }

    public record Basic(String name, String phone, String email) {}
    public record Avatar(String dataUrl) {}
    public record Password(String oldPassword, String newPassword) {}
}
