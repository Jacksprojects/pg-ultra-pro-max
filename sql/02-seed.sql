-- =============================================================================
-- Seed data — Sydney, Australia
-- All coordinates are (longitude, latitude) / SRID 4326
-- Timezone: Australia/Sydney (AEDT UTC+11 / AEST UTC+10)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Suburbs — stored as polygon boundaries (GEOGRAPHY GEOMETRY)
-- Coordinates are (longitude latitude) / WGS84.
-- Polygons are simplified real boundary approximations; each store point
-- has been verified to fall inside its suburb's polygon.
-- -----------------------------------------------------------------------------
INSERT INTO internal.suburbs (name, postcode, location) VALUES
    ('Surry Hills',  '2010', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2052 -33.8752, 151.2220 -33.8752, 151.2248 -33.8820,
        151.2230 -33.8998, 151.2095 -33.9012, 151.2038 -33.8952,
        151.2052 -33.8752))'), 4326)),
    ('Newtown',      '2042', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1698 -33.8875, 151.1952 -33.8875, 151.1965 -33.8930,
        151.1945 -33.9155, 151.1688 -33.9148, 151.1685 -33.8928,
        151.1698 -33.8875))'), 4326)),
    ('Bondi',        '2026', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2632 -33.8818, 151.2858 -33.8818, 151.2878 -33.8868,
        151.2858 -33.9012, 151.2635 -33.9008, 151.2618 -33.8875,
        151.2632 -33.8818))'), 4326)),
    ('Manly',        '2095', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2748 -33.7885, 151.2952 -33.7885, 151.2968 -33.7932,
        151.2948 -33.8088, 151.2745 -33.8082, 151.2732 -33.7935,
        151.2748 -33.7885))'), 4326)),
    ('Glebe',        '2037', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1775 -33.8698, 151.1998 -33.8698, 151.2005 -33.8748,
        151.1988 -33.8902, 151.1772 -33.8895, 151.1762 -33.8752,
        151.1775 -33.8698))'), 4326)),
    ('Parramatta',   '2150', ST_SetSRID(ST_GeomFromText('POLYGON((
        150.9928 -33.8042, 151.0152 -33.8042, 151.0165 -33.8098,
        151.0148 -33.8255, 150.9925 -33.8248, 150.9915 -33.8102,
        150.9928 -33.8042))'), 4326)),
    ('Chatswood',    '2067', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1718 -33.7858, 151.1952 -33.7858, 151.1962 -33.7905,
        151.1945 -33.8082, 151.1715 -33.8075, 151.1705 -33.7908,
        151.1718 -33.7858))'), 4326)),
    ('Pyrmont',      '2009', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1878 -33.8618, 151.2045 -33.8618, 151.2052 -33.8655,
        151.2035 -33.8782, 151.1875 -33.8775, 151.1865 -33.8658,
        151.1878 -33.8618))'), 4326)),
    ('Leichhardt',   '2040', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1478 -33.8725, 151.1722 -33.8725, 151.1732 -33.8778,
        151.1715 -33.8935, 151.1475 -33.8928, 151.1465 -33.8782,
        151.1478 -33.8725))'), 4326)),
    ('Coogee',       '2034', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2478 -33.9112, 151.2682 -33.9112, 151.2692 -33.9158,
        151.2675 -33.9335, 151.2475 -33.9328, 151.2465 -33.9162,
        151.2478 -33.9112))'), 4326)),
    ('Redfern',      '2016', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1958 -33.8868, 151.2152 -33.8868, 151.2162 -33.8912,
        151.2145 -33.9032, 151.1955 -33.9025, 151.1945 -33.8915,
        151.1958 -33.8868))'), 4326)),
    ('Darlinghurst', '2010', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2118 -33.8688, 151.2282 -33.8688, 151.2292 -33.8732,
        151.2275 -33.8852, 151.2115 -33.8845, 151.2105 -33.8735,
        151.2118 -33.8688))'), 4326)),
    ('Erskineville', '2043', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1818 -33.8948, 151.2002 -33.8948, 151.2012 -33.8995,
        151.1995 -33.9108, 151.1815 -33.9102, 151.1805 -33.8998,
        151.1818 -33.8948))'), 4326)),
    ('Balmain',      '2041', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1668 -33.8518, 151.1882 -33.8518, 151.1892 -33.8562,
        151.1875 -33.8702, 151.1665 -33.8695, 151.1655 -33.8565,
        151.1668 -33.8518))'), 4326)),
    ('Neutral Bay',  '2089', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2078 -33.8258, 151.2282 -33.8258, 151.2292 -33.8302,
        151.2275 -33.8452, 151.2075 -33.8445, 151.2065 -33.8305,
        151.2078 -33.8258))'), 4326)),
    ('Rozelle',      '2039', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1618 -33.8518, 151.1822 -33.8518, 151.1832 -33.8562,
        151.1815 -33.8722, 151.1615 -33.8715, 151.1605 -33.8565,
        151.1618 -33.8518))'), 4326)),
    ('Marrickville', '2204', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1458 -33.9028, 151.1682 -33.9028, 151.1692 -33.9075,
        151.1675 -33.9228, 151.1455 -33.9222, 151.1445 -33.9078,
        151.1458 -33.9028))'), 4326)),
    ('Randwick',     '2031', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2318 -33.9042, 151.2522 -33.9042, 151.2532 -33.9088,
        151.2515 -33.9282, 151.2315 -33.9275, 151.2305 -33.9092,
        151.2318 -33.9042))'), 4326)),
    ('Paddington',   '2021', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2198 -33.8768, 151.2402 -33.8768, 151.2412 -33.8812,
        151.2395 -33.8952, 151.2195 -33.8945, 151.2185 -33.8815,
        151.2198 -33.8768))'), 4326)),
    ('Woollahra',    '2025', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2348 -33.8778, 151.2552 -33.8778, 151.2562 -33.8822,
        151.2545 -33.8952, 151.2345 -33.8945, 151.2335 -33.8825,
        151.2348 -33.8778))'), 4326)),
    ('Mosman',       '2088', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2348 -33.8178, 151.2572 -33.8178, 151.2582 -33.8222,
        151.2565 -33.8382, 151.2345 -33.8375, 151.2335 -33.8225,
        151.2348 -33.8178))'), 4326)),
    ('Cremorne',     '2090', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2178 -33.8198, 151.2382 -33.8198, 151.2392 -33.8242,
        151.2375 -33.8402, 151.2175 -33.8395, 151.2165 -33.8245,
        151.2178 -33.8198))'), 4326)),
    ('Lane Cove',    '2066', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1578 -33.8058, 151.1802 -33.8058, 151.1812 -33.8102,
        151.1795 -33.8262, 151.1575 -33.8255, 151.1565 -33.8105,
        151.1578 -33.8058))'), 4326)),
    ('Artarmon',     '2064', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1758 -33.7978, 151.1962 -33.7978, 151.1972 -33.8022,
        151.1955 -33.8182, 151.1755 -33.8175, 151.1745 -33.8025,
        151.1758 -33.7978))'), 4326)),
    ('St Leonards',  '2065', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1858 -33.8128, 151.2062 -33.8128, 151.2072 -33.8172,
        151.2055 -33.8302, 151.1855 -33.8295, 151.1845 -33.8175,
        151.1858 -33.8128))'), 4326)),
    ('Ultimo',       '2007', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1898 -33.8728, 151.2062 -33.8728, 151.2072 -33.8772,
        151.2055 -33.8872, 151.1895 -33.8865, 151.1885 -33.8775,
        151.1898 -33.8728))'), 4326)),
    ('Chippendale',  '2008', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1928 -33.8828, 151.2112 -33.8828, 151.2122 -33.8872,
        151.2105 -33.8982, 151.1925 -33.8975, 151.1915 -33.8875,
        151.1928 -33.8828))'), 4326)),
    ('Alexandria',   '2015', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1918 -33.8958, 151.2122 -33.8958, 151.2132 -33.9002,
        151.2115 -33.9142, 151.1915 -33.9135, 151.1905 -33.9005,
        151.1918 -33.8958))'), 4326)),
    ('Waterloo',     '2017', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1998 -33.8928, 151.2192 -33.8928, 151.2202 -33.8972,
        151.2185 -33.9102, 151.1995 -33.9095, 151.1985 -33.8975,
        151.1998 -33.8928))'), 4326)),
    ('Zetland',      '2017', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2038 -33.8998, 151.2222 -33.8998, 151.2232 -33.9042,
        151.2215 -33.9132, 151.2035 -33.9125, 151.2025 -33.9045,
        151.2038 -33.8998))'), 4326)),
    ('Rosebery',     '2018', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1978 -33.9058, 151.2162 -33.9058, 151.2172 -33.9102,
        151.2155 -33.9222, 151.1975 -33.9215, 151.1965 -33.9105,
        151.1978 -33.9058))'), 4326)),
    ('Kensington',   '2033', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2168 -33.8978, 151.2342 -33.8978, 151.2352 -33.9022,
        151.2335 -33.9152, 151.2165 -33.9145, 151.2155 -33.9025,
        151.2168 -33.8978))'), 4326)),
    ('Maroubra',     '2035', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.2438 -33.9388, 151.2638 -33.9388, 151.2648 -33.9432,
        151.2632 -33.9582, 151.2435 -33.9575, 151.2425 -33.9435,
        151.2438 -33.9388))'), 4326)),
    ('Cronulla',     '2230', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.1445 -34.0478, 151.1638 -34.0478, 151.1648 -34.0528,
        151.1632 -34.0668, 151.1442 -34.0662, 151.1432 -34.0532,
        151.1445 -34.0478))'), 4326)),
    ('Hornsby',      '2077', ST_SetSRID(ST_GeomFromText('POLYGON((
        151.0888 -33.6928, 151.1112 -33.6928, 151.1122 -33.6978,
        151.1105 -33.7148, 151.0885 -33.7142, 151.0875 -33.6982,
        151.0888 -33.6928))'), 4326));

-- -----------------------------------------------------------------------------
-- Stores
-- -----------------------------------------------------------------------------
-- Store coordinates based on real Domino's Pizza locations in Sydney.
-- Each point has been verified to fall within its suburb's polygon boundary.
INSERT INTO internal.stores (name, address, suburb_id, location, phone) VALUES
    (
        'Slices – Surry Hills',
        '258 Crown St, Surry Hills NSW 2010',
        (SELECT id FROM internal.suburbs WHERE name = 'Surry Hills'),
        ST_SetSRID(ST_MakePoint(151.2147, -33.8840), 4326),  -- Domino's Crown St
        '(02) 9111 0001'
    ),
    (
        'Slices – Newtown',
        '321 King St, Newtown NSW 2042',
        (SELECT id FROM internal.suburbs WHERE name = 'Newtown'),
        ST_SetSRID(ST_MakePoint(151.1793, -33.8983), 4326),  -- Domino's King St
        '(02) 9111 0002'
    ),
    (
        'Slices – Bondi Beach',
        '138 Campbell Parade, Bondi Beach NSW 2026',
        (SELECT id FROM internal.suburbs WHERE name = 'Bondi'),
        ST_SetSRID(ST_MakePoint(151.2743, -33.8912), 4326),  -- Domino's Campbell Parade
        '(02) 9111 0003'
    ),
    (
        'Slices – Manly',
        '8 Whistler St, Manly NSW 2095',
        (SELECT id FROM internal.suburbs WHERE name = 'Manly'),
        ST_SetSRID(ST_MakePoint(151.2840, -33.7971), 4326),  -- Domino's Whistler St
        '(02) 9111 0004'
    ),
    (
        'Slices – Parramatta',
        '269 Church St, Parramatta NSW 2150',
        (SELECT id FROM internal.suburbs WHERE name = 'Parramatta'),
        ST_SetSRID(ST_MakePoint(151.0045, -33.8153), 4326),  -- Domino's Church St
        '(02) 9111 0005'
    ),
    (
        'Slices – Paddington',
        '283 Oxford St, Paddington NSW 2021',
        (SELECT id FROM internal.suburbs WHERE name = 'Paddington'),
        ST_SetSRID(ST_MakePoint(151.2295, -33.8858), 4326),  -- Domino's Oxford St
        '(02) 9111 0006'
    ),
    (
        'Slices – Marrickville',
        '289 Marrickville Rd, Marrickville NSW 2204',
        (SELECT id FROM internal.suburbs WHERE name = 'Marrickville'),
        ST_SetSRID(ST_MakePoint(151.1548, -33.9115), 4326),  -- Domino's Marrickville Rd
        '(02) 9111 0007'
    ),
    (
        'Slices – Mosman',
        '816 Military Rd, Mosman NSW 2088',
        (SELECT id FROM internal.suburbs WHERE name = 'Mosman'),
        ST_SetSRID(ST_MakePoint(151.2445, -33.8272), 4326),  -- Domino's Military Rd
        '(02) 9111 0008'
    ),
    (
        'Slices – Randwick',
        '143 Belmore Rd, Randwick NSW 2031',
        (SELECT id FROM internal.suburbs WHERE name = 'Randwick'),
        ST_SetSRID(ST_MakePoint(151.2413, -33.9162), 4326),  -- Domino's Belmore Rd
        '(02) 9111 0009'
    ),
    (
        'Slices – Cronulla',
        '16 Cronulla St, Cronulla NSW 2230',
        (SELECT id FROM internal.suburbs WHERE name = 'Cronulla'),
        ST_SetSRID(ST_MakePoint(151.1528, -34.0558), 4326),  -- Domino's Cronulla St
        '(02) 9111 0010'
    );

-- -----------------------------------------------------------------------------
-- Opening hours  (Mon–Thu 11:00–22:00 | Fri–Sat 11:00–23:00 | Sun 12:00–21:00)
-- -----------------------------------------------------------------------------
INSERT INTO internal.store_hours (store_id, day_of_week, open_time, close_time)
SELECT
    s.id,
    d.dow,
    CASE
        WHEN d.dow = 7 THEN '12:00'::TIME   -- Sunday opens later
        ELSE '11:00'::TIME
    END,
    CASE
        WHEN d.dow IN (5, 6) THEN '23:00'::TIME  -- Fri & Sat close later
        WHEN d.dow = 7       THEN '21:00'::TIME  -- Sunday closes earlier
        ELSE '22:00'::TIME
    END
FROM internal.stores s
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7)) AS d(dow);

-- -----------------------------------------------------------------------------
-- Menu categories
-- -----------------------------------------------------------------------------
INSERT INTO internal.menu_categories (name, display_name) VALUES
    ('starter',    'Starters'),
    ('classic',    'Classic Pizzas'),
    ('vegetarian', 'Vegetarian Pizzas'),
    ('special',    'Chef''s Specials');

-- -----------------------------------------------------------------------------
-- Pizza sizes & bases
-- -----------------------------------------------------------------------------
INSERT INTO internal.pizza_sizes (name, diameter_cm) VALUES
    ('personal', 20),
    ('small',    25),
    ('medium',   30),
    ('large',    35),
    ('xl',       40);

INSERT INTO internal.pizza_bases (name) VALUES
    ('classic'),
    ('thin'),
    ('thick'),
    ('stuffed_crust'),
    ('gluten_free');

-- -----------------------------------------------------------------------------
-- Menu items
-- -----------------------------------------------------------------------------
-- Starters
INSERT INTO internal.menu_items (category_id, name, description, base_price) VALUES
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'starter'),
        'Garlic Bread',
        'Toasted sourdough with roasted garlic butter and fresh parsley',
        8.50
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'starter'),
        'Loaded Potato Skins',
        'Crispy potato skins with sour cream, bacon bits and spring onion',
        12.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'starter'),
        'Bruschetta',
        'Grilled ciabatta with heirloom tomato, basil and aged balsamic',
        11.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'starter'),
        'Calamari',
        'Salt-and-pepper squid with house-made aioli and a lemon wedge',
        14.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'starter'),
        'Arancini (3 pcs)',
        'Fried risotto balls stuffed with mozzarella, served with napoli sauce',
        13.00
    );

-- Classic pizzas  (base_price = personal price; variants fill other sizes)
INSERT INTO internal.menu_items (category_id, name, description, base_price) VALUES
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'classic'),
        'Margherita',
        'San Marzano tomato, fior di latte mozzarella, fresh basil, extra virgin olive oil',
        15.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'classic'),
        'Pepperoni',
        'Tomato base, mozzarella, double pepperoni',
        17.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'classic'),
        'Ham & Pineapple',
        'Tomato base, mozzarella, leg ham, pineapple',
        17.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'classic'),
        'BBQ Chicken',
        'BBQ sauce base, mozzarella, grilled chicken, red onion, roasted capsicum',
        18.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'classic'),
        'Meat Lovers',
        'Tomato base, mozzarella, pepperoni, Italian sausage, bacon, leg ham',
        20.00
    );

-- Vegetarian pizzas
INSERT INTO internal.menu_items (category_id, name, description, base_price) VALUES
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'vegetarian'),
        'Garden Patch',
        'Tomato base, mozzarella, roasted pumpkin, spinach, mushroom, red onion, feta',
        17.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'vegetarian'),
        'Truffle Mushroom',
        'White sauce base, mozzarella, mixed wild mushrooms, truffle oil, rocket, parmesan',
        19.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'vegetarian'),
        'Caprese',
        'Pesto base, buffalo mozzarella, heirloom tomato, fresh basil, balsamic glaze',
        18.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'vegetarian'),
        'Roasted Veggie',
        'Tomato base, mozzarella, zucchini, capsicum, eggplant, olives, sun-dried tomato',
        17.00
    );

-- Specials
INSERT INTO internal.menu_items (category_id, name, description, base_price) VALUES
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'special'),
        'Sydney Prawn & Chilli',
        'Garlic cream base, mozzarella, tiger prawns, fresh chilli, lemon zest, rocket',
        24.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'special'),
        'Smoked Salmon & Capers',
        'Crème fraîche base, mozzarella, smoked salmon, capers, red onion, dill',
        23.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'special'),
        'Duck Confit & Hoisin',
        'Hoisin base, mozzarella, pulled duck confit, spring onion, sesame, cucumber',
        25.00
    ),
    (
        (SELECT id FROM internal.menu_categories WHERE name = 'special'),
        'Fig, Prosciutto & Gorgonzola',
        'White base, mozzarella, prosciutto, fresh figs, gorgonzola, honey, walnuts',
        24.00
    );

-- -----------------------------------------------------------------------------
-- Pizza variants — size/base/price matrix for all pizza items
-- (starters have no variants; they use base_price directly)
-- -----------------------------------------------------------------------------
INSERT INTO internal.menu_item_variants (menu_item_id, size_id, base_id, price)
SELECT
    mi.id,
    ps.id,
    pb.id,
    -- Price formula: base_price + size surcharge + base surcharge
    mi.base_price
        + CASE ps.name
            WHEN 'personal' THEN 0
            WHEN 'small'    THEN 3
            WHEN 'medium'   THEN 6
            WHEN 'large'    THEN 10
            WHEN 'xl'       THEN 14
          END
        + CASE pb.name
            WHEN 'classic'       THEN 0
            WHEN 'thin'          THEN 0
            WHEN 'thick'         THEN 1
            WHEN 'stuffed_crust' THEN 3
            WHEN 'gluten_free'   THEN 3
          END
FROM internal.menu_items      mi
JOIN internal.pizza_sizes     ps ON TRUE
JOIN internal.pizza_bases     pb ON TRUE
WHERE mi.category_id IN (
    SELECT id FROM internal.menu_categories
    WHERE name IN ('classic', 'vegetarian', 'special')
);

-- -----------------------------------------------------------------------------
-- Demo users
-- Passwords are bcrypt-hashed. Plaintext credentials are in README.md.
-- -----------------------------------------------------------------------------
INSERT INTO internal.users (email, password_hash, first_name, last_name, suburb_id, role)
VALUES
    (
        'demo@slices.com.au',
        crypt('password123', gen_salt('bf', 8)),
        'Alex',
        'Taylor',
        (SELECT id FROM internal.suburbs WHERE name = 'Surry Hills'),
        'customer'
    ),
    (
        'staff@slices.com.au',
        crypt('password123', gen_salt('bf', 8)),
        'Jordan',
        'Kim',
        (SELECT id FROM internal.suburbs WHERE name = 'Surry Hills'),
        'staff'
    );

-- -----------------------------------------------------------------------------
-- Demo orders for demo@slices.com.au
-- Inserted directly (bypassing api.place_order) so we can set specific
-- statuses and timestamps to show a realistic order history on first boot.
--
-- Prices:
--   Margherita      large  classic      = 15 + 10 + 0  = $25.00
--   Garlic Bread    (starter)           =               $8.50
--   Meat Lovers     medium thin         = 20 +  6 + 0  = $26.00
--   Calamari        (starter)           =               $14.00
--   Sydney Prawn    large  classic      = 24 + 10 + 0  = $34.00
--   Arancini        (starter)           =               $13.00
--   Pepperoni       xl     stuffed_crust= 17 + 14 + 3  = $34.00
--   Bruschetta      (starter)           =               $11.00
--   Garden Patch    medium classic      = 17 +  6 + 0  = $23.00
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_customer_id UUID;
    v_store_surry UUID;
    v_store_bondi UUID;

    v_margherita   UUID;
    v_meat_lovers  UUID;
    v_prawn_chilli UUID;
    v_pepperoni    UUID;
    v_garden_patch UUID;
    v_garlic_bread UUID;
    v_calamari     UUID;
    v_bruschetta   UUID;
    v_arancini     UUID;

    v_marg_large_classic     UUID;
    v_meat_medium_thin       UUID;
    v_prawn_large_classic    UUID;
    v_pep_xl_stuffed         UUID;
    v_garden_medium_classic  UUID;

    v_order1 UUID;
    v_order2 UUID;
    v_order3 UUID;
    v_order4 UUID;
BEGIN
    SELECT id INTO v_customer_id FROM internal.users  WHERE email = 'demo@slices.com.au';
    SELECT id INTO v_store_surry FROM internal.stores WHERE name  = 'Slices – Surry Hills';
    SELECT id INTO v_store_bondi FROM internal.stores WHERE name  = 'Slices – Bondi';

    SELECT id INTO v_margherita   FROM internal.menu_items WHERE name = 'Margherita';
    SELECT id INTO v_meat_lovers  FROM internal.menu_items WHERE name = 'Meat Lovers';
    SELECT id INTO v_prawn_chilli FROM internal.menu_items WHERE name = 'Sydney Prawn & Chilli';
    SELECT id INTO v_pepperoni    FROM internal.menu_items WHERE name = 'Pepperoni';
    SELECT id INTO v_garden_patch FROM internal.menu_items WHERE name = 'Garden Patch';
    SELECT id INTO v_garlic_bread FROM internal.menu_items WHERE name = 'Garlic Bread';
    SELECT id INTO v_calamari     FROM internal.menu_items WHERE name = 'Calamari';
    SELECT id INTO v_bruschetta   FROM internal.menu_items WHERE name = 'Bruschetta';
    SELECT id INTO v_arancini     FROM internal.menu_items WHERE name = 'Arancini (3 pcs)';

    SELECT v.id INTO v_marg_large_classic
    FROM internal.menu_item_variants v
    JOIN internal.pizza_sizes ps ON ps.id = v.size_id
    JOIN internal.pizza_bases pb ON pb.id = v.base_id
    WHERE v.menu_item_id = v_margherita AND ps.name = 'large' AND pb.name = 'classic';

    SELECT v.id INTO v_meat_medium_thin
    FROM internal.menu_item_variants v
    JOIN internal.pizza_sizes ps ON ps.id = v.size_id
    JOIN internal.pizza_bases pb ON pb.id = v.base_id
    WHERE v.menu_item_id = v_meat_lovers AND ps.name = 'medium' AND pb.name = 'thin';

    SELECT v.id INTO v_prawn_large_classic
    FROM internal.menu_item_variants v
    JOIN internal.pizza_sizes ps ON ps.id = v.size_id
    JOIN internal.pizza_bases pb ON pb.id = v.base_id
    WHERE v.menu_item_id = v_prawn_chilli AND ps.name = 'large' AND pb.name = 'classic';

    SELECT v.id INTO v_pep_xl_stuffed
    FROM internal.menu_item_variants v
    JOIN internal.pizza_sizes ps ON ps.id = v.size_id
    JOIN internal.pizza_bases pb ON pb.id = v.base_id
    WHERE v.menu_item_id = v_pepperoni AND ps.name = 'xl' AND pb.name = 'stuffed_crust';

    SELECT v.id INTO v_garden_medium_classic
    FROM internal.menu_item_variants v
    JOIN internal.pizza_sizes ps ON ps.id = v.size_id
    JOIN internal.pizza_bases pb ON pb.id = v.base_id
    WHERE v.menu_item_id = v_garden_patch AND ps.name = 'medium' AND pb.name = 'classic';

    -- Order 1 — processed, 2 weeks ago, Surry Hills
    -- Margherita large classic x1 ($25) + Garlic Bread x2 ($8.50 each) = $42.00
    INSERT INTO internal.orders
        (user_id, store_id, status, delivery_address, total_amount, created_at, updated_at)
    VALUES (
        v_customer_id, v_store_surry, 'processed',
        '12 Riley St, Surry Hills NSW 2010', 42.00,
        NOW() - INTERVAL '14 days', NOW() - INTERVAL '14 days' + INTERVAL '28 minutes'
    ) RETURNING id INTO v_order1;

    INSERT INTO internal.order_items (order_id, item_id, variant_id, quantity, unit_price) VALUES
        (v_order1, v_margherita,   v_marg_large_classic, 1, 25.00),
        (v_order1, v_garlic_bread, NULL,                 2,  8.50);

    -- Order 2 — processed, 1 week ago, Bondi
    -- Meat Lovers medium thin x1 ($26) + Calamari x1 ($14) = $40.00
    INSERT INTO internal.orders
        (user_id, store_id, status, delivery_address, total_amount, created_at, updated_at)
    VALUES (
        v_customer_id, v_store_bondi, 'processed',
        '22 Hall St, Bondi NSW 2026', 40.00,
        NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days' + INTERVAL '32 minutes'
    ) RETURNING id INTO v_order2;

    INSERT INTO internal.order_items (order_id, item_id, variant_id, quantity, unit_price) VALUES
        (v_order2, v_meat_lovers, v_meat_medium_thin, 1, 26.00),
        (v_order2, v_calamari,    NULL,               1, 14.00);

    -- Order 3 — processing (in the kitchen right now), Surry Hills
    -- Sydney Prawn & Chilli large classic x1 ($34) + Arancini x1 ($13) = $47.00
    INSERT INTO internal.orders
        (user_id, store_id, status, delivery_address, total_amount, created_at, updated_at)
    VALUES (
        v_customer_id, v_store_surry, 'processing',
        '12 Riley St, Surry Hills NSW 2010', 47.00,
        NOW() - INTERVAL '20 minutes', NOW() - INTERVAL '8 minutes'
    ) RETURNING id INTO v_order3;

    INSERT INTO internal.order_items (order_id, item_id, variant_id, quantity, unit_price) VALUES
        (v_order3, v_prawn_chilli, v_prawn_large_classic, 1, 34.00),
        (v_order3, v_arancini,     NULL,                  1, 13.00);

    -- Order 4 — pending (just placed), Surry Hills
    -- Pepperoni XL stuffed crust x1 ($34) + Bruschetta x1 ($11) + Garden Patch medium classic x1 ($23) = $68.00
    INSERT INTO internal.orders
        (user_id, store_id, status, delivery_address, total_amount, created_at, updated_at)
    VALUES (
        v_customer_id, v_store_surry, 'pending',
        '12 Riley St, Surry Hills NSW 2010', 68.00,
        NOW() - INTERVAL '2 minutes', NOW() - INTERVAL '2 minutes'
    ) RETURNING id INTO v_order4;

    INSERT INTO internal.order_items (order_id, item_id, variant_id, quantity, unit_price) VALUES
        (v_order4, v_pepperoni,    v_pep_xl_stuffed,       1, 34.00),
        (v_order4, v_bruschetta,   NULL,                   1, 11.00),
        (v_order4, v_garden_patch, v_garden_medium_classic, 1, 23.00);
END $$;
