#!/bin/bash

cd /root/spree_starter || exit 1

# List of categories
categories=(
"Necklace & Pendants"
"Adult Wellness"
"Lady Dresses"
"Lipstick"
"Home Office Storage"
"Wall Lamps"
"Solid"
"Ceiling Lights"
"Bras"
"Fashion Jewelry Sets"
"Bracelets & Bangles"
"Flats"
"Stuffed & Plush Animals"
"Blazers"
"Earrings"
"Blouses & Shirts"
"Rings"
"Print"
"Wide Leg Pants"
"Woman Trench"
"Suits & Sets"
"Smart Wearable Accessories"
"Women's Padded Jackets"
"Casual Pants"
"Totes"
"Basic Jacket"
"Sweaters"
"Fashion Backpacks"
"Woman Sandals"
"Sleep & Lounge"
"External Hard Drives"
"Casual Shoes"
"Cake Decorating Supplies"
"Dress Watches"
"Women's Crossbody Bags"
"Crossbody Bags"
"Men's Sweaters"
"Fitness & Bodybuilding"
"Action & Toy Figures"
"Kitchen Storage"
"Belts & Cummerbunds"
"Storage Bottles & Jars"
"Suits & Blazer"
"Car Washer"
"Storage Bags & Cases & Boxes"
"Pillows"
"Pumps"
"Bedding Sets"
"Body Care"
"Women's Long-Sleeved Shirts"
"Headband & Hair Band & Hairpin"
"Scarves & Wraps"
"Woman Gloves & Mittens"
"Men's Suits"
"Hand Tools"
"Decorative Flowers & Wreaths"
"Pants & Capris"
"Facial Care"
"Woman Jeans"
"Personal Care Appliances"
"Skirts"
"Pet Nests"
"Keychains"
"Women's Short-Sleeved Shirts"
"Outdoor Shorts"
"Men's Jackets"
"Dinnerware"
"Trainers"
"Men Sports Watches"
"Woman Socks"
"Woman Hoodies & Sweatshirts"
"Panties"
"Woman Hats & Caps"
"Formal Shoes"
"Event & Party Supplies"
)

# File to store last picked category
LAST_PICK_FILE="/root/spree_starter/.last_cj_category"

# Read last picked category
if [ -f "$LAST_PICK_FILE" ]; then
  last_category=$(cat "$LAST_PICK_FILE")
else
  last_category=""
fi

# Filter categories to exclude last picked
available_categories=()
for cat in "${categories[@]}"; do
  if [ "$cat" != "$last_category" ]; then
    available_categories+=("$cat")
  fi
done

# Pick a random category from available ones
RANDOM_INDEX=$(( RANDOM % ${#available_categories[@]} ))
category="${available_categories[$RANDOM_INDEX]}"

echo "[CJ] Randomly selected category: $category"

# Save this category as last picked
echo "$category" > "$LAST_PICK_FILE"

# Run CJ fetch and mapping commands
CJ_CATEGORY_NAME="$category" bin/rails cj:full_product_test
CJ_CATEGORY_NAME="$category" bin/rails wuhugoods:create_and_map
