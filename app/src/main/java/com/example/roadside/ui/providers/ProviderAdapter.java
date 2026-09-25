package com.example.roadside.ui.providers;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.roadside.R;
import com.example.roadside.data.models.Provider;
import com.example.roadside.utils.LocationHelper;

import java.util.ArrayList;
import java.util.List;

public class ProviderAdapter extends RecyclerView.Adapter<ProviderAdapter.ViewHolder> {

    public interface OnProviderClickListener {
        void onProviderClick(Provider provider);
    }

    private List<Provider> providerList = new ArrayList<>();
    private final OnProviderClickListener listener;

    public ProviderAdapter(OnProviderClickListener listener) {
        this.listener = listener;
    }

    public void setProviders(List<Provider> providers) {
        this.providerList = providers != null ? providers : new ArrayList<>();
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_provider, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Provider provider = providerList.get(position);
        holder.tvName.setText(provider.getName());
        holder.tvRating.setText("⭐ " + provider.getRating() + " (Đánh giá) • Chuyên nghiệp");
        holder.tvDistance.setText("🚗 " + LocationHelper.formatDistance(provider.getDistance()));
        if (holder.tvPrice != null) {
            holder.tvPrice.setText("350.000 VNĐ");
        }
        holder.btnSelect.setOnClickListener(v -> {
            if (listener != null) {
                listener.onProviderClick(provider);
            }
        });
    }

    @Override
    public int getItemCount() {
        return providerList.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        TextView tvName, tvRating, tvDistance, tvPrice;
        Button btnSelect;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            tvName = itemView.findViewById(R.id.tvProviderName);
            tvRating = itemView.findViewById(R.id.tvProviderRatingMeta);
            tvDistance = itemView.findViewById(R.id.tvProviderDistance);
            tvPrice = itemView.findViewById(R.id.tvProviderPrice);
            btnSelect = itemView.findViewById(R.id.btnChooseProvider);
        }
    }
}
