package com.example.roadside.data.db;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

import com.example.roadside.data.models.Request;
import com.example.roadside.data.models.User;

@Database(entities = {User.class, Request.class}, version = 1, exportSchema = false)
public abstract class AppDatabase extends RoomDatabase {

    private static volatile AppDatabase INSTANCE;

    public abstract UserDao userDao();
    public abstract RequestDao requestDao();

    public static AppDatabase getInstance(Context context) {
        if (INSTANCE == null) {
            synchronized (AppDatabase.class) {
                if (INSTANCE == null) {
                    INSTANCE = Room.databaseBuilder(
                            context.getApplicationContext(),
                            AppDatabase.class,
                            "roadside_db"
                    ).allowMainThreadQueries().build();
                }
            }
        }
        return INSTANCE;
    }
}
