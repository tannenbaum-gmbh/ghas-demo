package com.github.advancedsecurity.storageservice.controllers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Value;

@RestController
@CrossOrigin
public class SearchController {

    @Value("${spring.datasource.url:jdbc:h2:mem:testdb}")
    private String dbUrl;

    @Value("${spring.datasource.username:sa}")
    private String dbUser;

    @Value("${spring.datasource.password:}")
    private String dbPassword;

    // WARNING: This endpoint contains an intentional SQL injection vulnerability for GHAS demo purposes.
    @GetMapping("/search")
    public List<Map<String, String>> search(@RequestParam String query) {
        List<Map<String, String>> results = new ArrayList<>();
        try {
            Connection connection = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
            Statement statement = connection.createStatement();

            // SQL Injection vulnerability: user input is concatenated directly into the query
            String sql = "SELECT * FROM blobs WHERE name LIKE '%" + query + "%'";
            ResultSet rs = statement.executeQuery(sql);

            while (rs.next()) {
                Map<String, String> row = new HashMap<>();
                row.put("id", rs.getString("id"));
                row.put("name", rs.getString("name"));
                row.put("content_type", rs.getString("content_type"));
                results.add(row);
            }

            rs.close();
            statement.close();
            connection.close();
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Search failed: " + e.getMessage());
        }
        return results;
    }
}
