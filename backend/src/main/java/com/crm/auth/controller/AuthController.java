package com.crm.auth.controller;

import com.crm.auth.model.SessionUser;
import com.crm.profile.mapper.ProfileMapper;

import java.util.UUID;
import com.crm.auth.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private static final String EMPLOYEE_ID = "employeeId";
    private final AuthService service;
    private final ProfileMapper profiles;

    public AuthController(AuthService service, ProfileMapper profiles) {
        this.service = service;
        this.profiles = profiles;
    }

    @PostMapping("/login")
    public SessionUser login(@RequestBody Credentials form, HttpServletRequest request) {
        SessionUser user = service.login(form.username(), form.password());
        String loginId = UUID.randomUUID().toString();
        String device = request.getHeader("User-Agent");
        if (device == null) device = "Unknown";
        profiles.recordLogin(user.id(), loginId, device.substring(0, Math.min(device.length(), 255)), request.getRemoteAddr());
        HttpSession session = request.getSession();
        session.setAttribute("loginRecordId", loginId);
        request.changeSessionId();
        session.setAttribute(EMPLOYEE_ID, user.id());
        return user;
    }

    @GetMapping("/me")
    public SessionUser current(@SessionAttribute(name = EMPLOYEE_ID, required = false) Long id) {
        if (id == null) throw new org.springframework.web.server.ResponseStatusException(HttpStatus.UNAUTHORIZED);
        return service.current(id);
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session != null) session.invalidate();
    }

    public record Credentials(String username, String password) {}
}


