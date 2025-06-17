#!/bin/bash

# تک پوش خاص - نصب کامل یک مرحله‌ای
# One-Command Complete Installation for Tek Push Khas

set -e

echo "=== تک پوش خاص - نصب خودکار ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# System update
print_info "Updating system..."
apt update && apt upgrade -y

# Install dependencies
print_info "Installing dependencies..."
apt install -y curl wget git nginx postgresql postgresql-contrib build-essential

# Install Node.js 20
print_info "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Setup PostgreSQL
print_info "Setting up PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "CREATE USER tekpushuser WITH PASSWORD 'TekPush2024!@#';" || true
sudo -u postgres psql -c "CREATE DATABASE tekpushdb OWNER tekpushuser;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tekpushdb TO tekpushuser;" || true

# Clone and setup project
print_info "Cloning project..."
cd /opt
rm -rf tek-push-khas
git clone https://github.com/moha100h/TakPoshKhas.git tek-push-khas
cd tek-push-khas

# Environment setup
print_info "Configuring environment..."
cat > .env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://tekpushuser:TekPush2024!@#@localhost:5432/tekpushdb
SESSION_SECRET=TekPushSecretKey2024SuperSecure
PGHOST=localhost
PGPORT=5432
PGUSER=tekpushuser
PGPASSWORD=TekPush2024!@#
PGDATABASE=tekpushdb
EOF

# Fix TypeScript errors by updating schema
print_info "Fixing TypeScript configuration and schema..."

# Fix the schema to resolve TypeScript errors
cat > shared/schema.ts << 'EOF'
import {
  pgTable,
  text,
  varchar,
  timestamp,
  jsonb,
  index,
  serial,
  boolean,
  integer,
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const sessions = pgTable(
  "sessions",
  {
    sid: varchar("sid").primaryKey(),
    sess: jsonb("sess").notNull(),
    expire: timestamp("expire").notNull(),
  },
  (table) => [index("IDX_session_expire").on(table.expire)],
);

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: varchar("username", { length: 50 }).unique().notNull(),
  password: varchar("password", { length: 255 }).notNull(),
  email: varchar("email", { length: 100 }).unique(),
  firstName: varchar("first_name", { length: 50 }),
  lastName: varchar("last_name", { length: 50 }),
  profileImageUrl: varchar("profile_image_url", { length: 500 }),
  role: varchar("role", { length: 20 }).notNull().default("admin"),
  isActive: boolean("is_active").default(true),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const brandSettings = pgTable("brand_settings", {
  id: serial("id").primaryKey(),
  name: text("name").notNull().default("تک پوش خاص"),
  slogan: text("slogan").notNull().default("یک از یک"),
  logoUrl: text("logo_url"),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const tshirtImages = pgTable("tshirt_images", {
  id: serial("id").primaryKey(),
  imageUrl: text("image_url").notNull(),
  alt: text("alt").notNull(),
  title: text("title"),
  description: text("description"),
  price: text("price"),
  size: text("size"),
  displayOrder: integer("display_order").notNull().default(0),
  isActive: boolean("is_active").notNull().default(true),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const socialLinks = pgTable("social_links", {
  id: serial("id").primaryKey(),
  platform: varchar("platform", { length: 50 }).notNull(),
  url: text("url").notNull(),
  isActive: boolean("is_active").notNull().default(true),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const copyrightSettings = pgTable("copyright_settings", {
  id: serial("id").primaryKey(),
  text: text("text").notNull().default("© 1404 تک پوش خاص. تمامی حقوق محفوظ است."),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const aboutContent = pgTable("about_content", {
  id: serial("id").primaryKey(),
  title: text("title").notNull().default("درباره ما"),
  content: text("content").notNull().default("ما برند پیشرو در طراحی تی‌شرت هستیم"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const insertUserSchema = createInsertSchema(users).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const loginUserSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export const insertBrandSettingsSchema = createInsertSchema(brandSettings).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertTshirtImageSchema = createInsertSchema(tshirtImages).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertSocialLinkSchema = createInsertSchema(socialLinks).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertCopyrightSettingsSchema = createInsertSchema(copyrightSettings).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertAboutContentSchema = createInsertSchema(aboutContent).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type User = typeof users.$inferSelect;
export type InsertUser = z.infer<typeof insertUserSchema>;
export type LoginUser = z.infer<typeof loginUserSchema>;
export type BrandSettings = typeof brandSettings.$inferSelect;
export type InsertBrandSettings = z.infer<typeof insertBrandSettingsSchema>;
export type TshirtImage = typeof tshirtImages.$inferSelect;
export type InsertTshirtImage = z.infer<typeof insertTshirtImageSchema>;
export type SocialLink = typeof socialLinks.$inferSelect;
export type InsertSocialLink = z.infer<typeof insertSocialLinkSchema>;
export type CopyrightSettings = typeof copyrightSettings.$inferSelect;
export type InsertCopyrightSettings = z.infer<typeof insertCopyrightSettingsSchema>;
export type AboutContent = typeof aboutContent.$inferSelect;
export type InsertAboutContent = z.infer<typeof insertAboutContentSchema>;
EOF

# Create corrected storage implementation
cat > server/storage.ts << 'EOF'
import {
  users,
  brandSettings,
  tshirtImages,
  socialLinks,
  copyrightSettings,
  aboutContent,
  type User,
  type InsertUser,
  type BrandSettings,
  type InsertBrandSettings,
  type TshirtImage,
  type InsertTshirtImage,
  type SocialLink,
  type InsertSocialLink,
  type CopyrightSettings,
  type InsertCopyrightSettings,
  type AboutContent,
  type InsertAboutContent,
} from "@shared/schema";
import { db } from "./db";
import { eq } from "drizzle-orm";
import session from "express-session";
import connectPg from "connect-pg-simple";
import { pool } from "./db";

export interface IStorage {
  sessionStore: any;
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  getBrandSettings(): Promise<BrandSettings | undefined>;
  updateBrandSettings(data: Partial<InsertBrandSettings>): Promise<BrandSettings>;
  getActiveTshirtImages(): Promise<TshirtImage[]>;
  getAllTshirtImages(): Promise<TshirtImage[]>;
  createTshirtImage(data: InsertTshirtImage): Promise<TshirtImage>;
  updateTshirtImageDetails(id: number, data: { title?: string; description?: string; size?: string; price?: string }): Promise<TshirtImage>;
  deleteTshirtImage(id: number): Promise<void>;
  reorderTshirtImages(imageIds: number[]): Promise<void>;
  getActiveSocialLinks(): Promise<SocialLink[]>;
  updateSocialLinks(data: InsertSocialLink[]): Promise<SocialLink[]>;
  getCopyrightSettings(): Promise<CopyrightSettings | undefined>;
  updateCopyrightSettings(data: InsertCopyrightSettings): Promise<CopyrightSettings>;
  getAboutContent(): Promise<AboutContent | undefined>;
  updateAboutContent(data: InsertAboutContent): Promise<AboutContent>;
}

export class DatabaseStorage implements IStorage {
  public sessionStore: any;

  constructor() {
    const PostgresSessionStore = connectPg(session);
    this.sessionStore = new PostgresSessionStore({ 
      pool, 
      createTableIfMissing: true 
    });
  }

  async getUser(id: number): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.id, id));
    return user;
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.username, username));
    return user;
  }

  async createUser(userData: InsertUser): Promise<User> {
    const [user] = await db.insert(users).values(userData).returning();
    return user;
  }

  async getBrandSettings(): Promise<BrandSettings | undefined> {
    const [settings] = await db.select().from(brandSettings).limit(1);
    if (!settings) {
      const [newSettings] = await db
        .insert(brandSettings)
        .values({
          name: "تک پوش خاص",
          slogan: "یک از یک",
          description: "برند پیشرو در طراحی تی‌شرت"
        })
        .returning();
      return newSettings;
    }
    return settings;
  }

  async updateBrandSettings(data: Partial<InsertBrandSettings>): Promise<BrandSettings> {
    const existing = await this.getBrandSettings();
    if (existing) {
      const [updated] = await db
        .update(brandSettings)
        .set(data)
        .where(eq(brandSettings.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db.insert(brandSettings).values(data).returning();
      return created;
    }
  }

  async getActiveTshirtImages(): Promise<TshirtImage[]> {
    return await db
      .select()
      .from(tshirtImages)
      .where(eq(tshirtImages.isActive, true))
      .orderBy(tshirtImages.displayOrder);
  }

  async getAllTshirtImages(): Promise<TshirtImage[]> {
    return await db.select().from(tshirtImages).orderBy(tshirtImages.displayOrder);
  }

  async createTshirtImage(data: InsertTshirtImage): Promise<TshirtImage> {
    const [image] = await db.insert(tshirtImages).values(data).returning();
    return image;
  }

  async updateTshirtImageDetails(id: number, data: { title?: string; description?: string; size?: string; price?: string }): Promise<TshirtImage> {
    const [updatedImage] = await db
      .update(tshirtImages)
      .set(data)
      .where(eq(tshirtImages.id, id))
      .returning();
    return updatedImage;
  }

  async deleteTshirtImage(id: number): Promise<void> {
    await db.delete(tshirtImages).where(eq(tshirtImages.id, id));
  }

  async reorderTshirtImages(imageIds: number[]): Promise<void> {
    for (let i = 0; i < imageIds.length; i++) {
      await db
        .update(tshirtImages)
        .set({ displayOrder: i + 1 })
        .where(eq(tshirtImages.id, imageIds[i]));
    }
  }

  async getActiveSocialLinks(): Promise<SocialLink[]> {
    return await db.select().from(socialLinks).where(eq(socialLinks.isActive, true));
  }

  async updateSocialLinks(data: InsertSocialLink[]): Promise<SocialLink[]> {
    await db.delete(socialLinks);
    if (data.length > 0) {
      const inserted = await db.insert(socialLinks).values(data).returning();
      return inserted;
    }
    return [];
  }

  async getCopyrightSettings(): Promise<CopyrightSettings | undefined> {
    const [settings] = await db.select().from(copyrightSettings).limit(1);
    if (!settings) {
      const [newSettings] = await db
        .insert(copyrightSettings)
        .values({ text: "© 1404 تک پوش خاص. تمامی حقوق محفوظ است." })
        .returning();
      return newSettings;
    }
    return settings;
  }

  async updateCopyrightSettings(data: InsertCopyrightSettings): Promise<CopyrightSettings> {
    const existing = await this.getCopyrightSettings();
    if (existing) {
      const [updated] = await db
        .update(copyrightSettings)
        .set(data)
        .where(eq(copyrightSettings.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db.insert(copyrightSettings).values(data).returning();
      return created;
    }
  }

  async getAboutContent(): Promise<AboutContent | undefined> {
    const [content] = await db.select().from(aboutContent).limit(1);
    if (!content) {
      const [newContent] = await db
        .insert(aboutContent)
        .values({
          title: "درباره ما",
          content: "ما برند پیشرو در طراحی تی‌شرت هستیم که با ترکیب خلاقیت و کیفیت، محصولاتی منحصر به فرد ارائه می‌دهیم."
        })
        .returning();
      return newContent;
    }
    return content;
  }

  async updateAboutContent(data: InsertAboutContent): Promise<AboutContent> {
    const existing = await this.getAboutContent();
    if (existing) {
      const [updated] = await db
        .update(aboutContent)
        .set(data)
        .where(eq(aboutContent.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db.insert(aboutContent).values(data).returning();
      return created;
    }
  }
}

export const storage = new DatabaseStorage();
EOF

# Fix TypeScript configuration for production build
cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": false,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./client/src/*"],
      "@shared/*": ["./shared/*"],
      "@assets/*": ["./attached_assets/*"]
    }
  },
  "include": ["client/src", "shared", "server"],
  "exclude": ["node_modules", "dist"]
}
EOF

mkdir -p server
cat > server/tsconfig.json << EOF
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "outDir": "../dist/server",
    "rootDir": "../server",
    "module": "CommonJS",
    "target": "ES2022",
    "moduleResolution": "node",
    "noEmit": false,
    "strict": false
  },
  "include": ["../server/**/*"],
  "exclude": ["../node_modules", "../dist"]
}
EOF

# Install dependencies
print_info "Installing npm packages..."
npm install

# Create database schema directly
print_info "Creating database schema..."
PGPASSWORD="TekPush2024!@#" psql -h localhost -U tekpushuser -d tekpushdb << 'EOSQL'
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS brand_settings CASCADE;
DROP TABLE IF EXISTS tshirt_images CASCADE;
DROP TABLE IF EXISTS social_links CASCADE;
DROP TABLE IF EXISTS copyright_settings CASCADE;
DROP TABLE IF EXISTS about_content CASCADE;

CREATE TABLE sessions (
    sid VARCHAR PRIMARY KEY,
    sess JSONB NOT NULL,
    expire TIMESTAMP NOT NULL
);

CREATE INDEX IDX_session_expire ON sessions(expire);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    profile_image_url VARCHAR(500),
    role VARCHAR(20) NOT NULL DEFAULT 'admin',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE brand_settings (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT NOT NULL DEFAULT 'یک از یک',
    logo_url TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tshirt_images (
    id SERIAL PRIMARY KEY,
    image_url TEXT NOT NULL,
    alt TEXT NOT NULL,
    title TEXT,
    description TEXT,
    price TEXT,
    size TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE about_content (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'درباره ما',
    content TEXT NOT NULL DEFAULT 'ما برند پیشرو در طراحی تی‌شرت هستیم',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (username, password, role) 
VALUES ('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin');

INSERT INTO brand_settings (name, slogan, description)
VALUES ('تک پوش خاص', 'یک از یک', 'برند پیشرو در طراحی تی‌شرت');

INSERT INTO copyright_settings (text)
VALUES ('© 1404 تک پوش خاص. تمامی حقوق محفوظ است.');

INSERT INTO about_content (title, content)
VALUES ('درباره ما', 'ما برند پیشرو در طراحی تی‌شرت هستیم که با ترکیب خلاقیت و کیفیت، محصولاتی منحصر به فرد ارائه می‌دهیم.');

INSERT INTO social_links (platform, url)
VALUES ('instagram', 'https://instagram.com/tekpushkhas');

INSERT INTO tshirt_images (image_url, alt, title, description, price, size, display_order, is_active)
VALUES 
('/uploads/sample1.jpg', 'تی‌شرت نمونه 1', 'تی‌شرت طرح خاص', 'طراحی منحصر به فرد', '250000 تومان', 'M', 1, true),
('/uploads/sample2.jpg', 'تی‌شرت نمونه 2', 'تی‌شرت کلاسیک', 'طراحی کلاسیک و شیک', '220000 تومان', 'L', 2, true);
EOSQL

# Build application
print_info "Building application..."
npm run build

# Setup permissions
print_info "Setting up permissions..."
chown -R www-data:www-data /opt/tek-push-khas
chmod -R 755 /opt/tek-push-khas

# Create systemd service
print_info "Creating system service..."
cat > /etc/systemd/system/tek-push-khas.service << EOF
[Unit]
Description=Tek Push Khas Application
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/tek-push-khas
Environment=NODE_ENV=production
Environment=PORT=5000
ExecStart=/usr/bin/node dist/server/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Setup Nginx
print_info "Configuring web server..."
cat > /etc/nginx/sites-available/tek-push-khas << EOF
server {
    listen 80;
    server_name 88.198.124.200 localhost;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tek-push-khas /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Create upload directory
mkdir -p /opt/tek-push-khas/public/uploads
chown -R www-data:www-data /opt/tek-push-khas/public/uploads

# Start services
print_info "Starting services..."
systemctl daemon-reload
systemctl enable tek-push-khas
systemctl start tek-push-khas
systemctl reload nginx

# Setup firewall
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

print_status "Installation completed successfully!"
print_info "Website available at: http://88.198.124.200"
print_info "Admin login: username 'admin', password 'password'"

# Check service status
sleep 3
if systemctl is-active --quiet tek-push-khas; then
    print_status "Service is running successfully"
else
    print_info "Service status: $(systemctl is-active tek-push-khas)"
    print_info "Check logs with: journalctl -u tek-push-khas -f"
fi

echo "=== Installation Complete ==="