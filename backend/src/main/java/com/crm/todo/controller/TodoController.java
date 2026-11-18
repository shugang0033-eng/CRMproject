package com.crm.todo.controller;

import com.crm.todo.service.TodoService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/todos")
public class TodoController {
    private final TodoService todos;

    public TodoController(TodoService todos) {
        this.todos=todos;
    }

    @GetMapping
    public Object list(@SessionAttribute Long employeeId) {
        return todos.list(employeeId);
    }
}