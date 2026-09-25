package com.example.roadside.data.db;

import androidx.room.Dao;
import androidx.room.Delete;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import com.example.roadside.data.models.Request;

import java.util.List;

@Dao
public interface RequestDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    long insert(Request request);

    @Update
    void update(Request request);

    @Delete
    void delete(Request request);

    @Query("SELECT * FROM requests WHERE userId = :userId ORDER BY id DESC")
    List<Request> getRequestsByUserId(int userId);

    @Query("SELECT * FROM requests WHERE id = :id LIMIT 1")
    Request getRequestById(int id);

    @Query("SELECT * FROM requests ORDER BY id DESC")
    List<Request> getAllRequests();
}
