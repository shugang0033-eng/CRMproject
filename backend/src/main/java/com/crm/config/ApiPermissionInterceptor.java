package com.crm.config;

import com.crm.auth.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.server.ResponseStatusException;

@Component
public class ApiPermissionInterceptor implements HandlerInterceptor {
    private final AuthService auth;

    public ApiPermissionInterceptor(AuthService auth) {
        this.auth = auth;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,HttpServletResponse response,Object handler) {
        var session = request.getSession(false);
        if (session == null || !(session.getAttribute("employeeId") instanceof Long employeeId)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"请先登录");
        }
        // 每次从数据库读取，停用账号和撤销权限即时生效。
        var permissions = auth.current(employeeId).permissions();
        String path = request.getRequestURI().substring(request.getContextPath().length());
        boolean read = request.getMethod().equals("GET") || request.getMethod().equals("HEAD");
        String permission = null;
        if (path.matches("/api/employees/[^/]+/roles")) {
            permission = "employee.manage";
        } else if (path.equals("/api/employees") || path.startsWith("/api/employees/")) {
            permission = read ? "employee.view" : "employee.manage";
        } else if (path.equals("/api/departments") || path.startsWith("/api/departments/")) {
            permission = read ? "dept.view" : "dept.manage";
        } else if (path.equals("/api/roles") || path.startsWith("/api/roles/")) {
            permission = read ? "role.view" : "role.manage";
        }
        if (permission != null && !permissions.contains(permission)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,"没有该操作权限");
        }
        return true;
    }
}
