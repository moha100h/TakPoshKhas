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

// Session storage table - required for Replit Auth
export const sessions = pgTable(
  "sessions",
  {
    sid: varchar("sid").primaryKey(),
    sess: jsonb("sess").notNull(),
    expire: timestamp("expire").notNull(),
  },
  (table) => [index("IDX_session_expire").on(table.expire)],
);

// User storage table for username/password authentication
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

// Brand settings table
export const brandSettings = pgTable("brand_settings", {
  id: serial("id").primaryKey(),
  name: text("name").notNull().default("تک پوش خاص"),
  slogan: text("slogan").notNull().default("یک از یک"),
  logoUrl: text("logo_url"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// T-shirt images table
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

// Social media links table
export const socialLinks = pgTable("social_links", {
  id: serial("id").primaryKey(),
  platform: text("platform").notNull(), // instagram, telegram, tiktok, youtube
  url: text("url").notNull(),
  isActive: boolean("is_active").notNull().default(true),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Copyright settings table
export const copyrightSettings = pgTable("copyright_settings", {
  id: serial("id").primaryKey(),
  text: text("text").notNull().default("© ۱۴۰۳ تک پوش خاص. تمامی حقوق محفوظ است."),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// About page content table
export const aboutContent = pgTable("about_content", {
  id: serial("id").primaryKey(),
  title: text("title").notNull().default("درباره تک پوش خاص"),
  subtitle: text("subtitle").notNull().default("ما برندی هستیم که در خلق پوشاک منحصر به فرد تخصص داریم"),
  philosophyTitle: text("philosophy_title").notNull().default("فلسفه ما"),
  philosophyText1: text("philosophy_text1").notNull().default("در تک پوش خاص، ما معتقدیم که هر فرد منحصر به فرد است و پوشاک او نیز باید این منحصر به فرد بودن را منعکس کند."),
  philosophyText2: text("philosophy_text2").notNull().default("شعار ما \"یک از یک\" نشان‌دهنده تعهد ما به ارائه محصولاتی است که در هیچ جای دیگری پیدا نخواهید کرد."),
  contactTitle: text("contact_title").notNull().default("تماس با ما"),
  contactEmail: text("contact_email").notNull().default("info@tekpooshkhaas.com"),
  contactPhone: text("contact_phone").notNull().default("۰۹۱۲۳۴۵۶۷۸۹"),
  contactAddress: text("contact_address").notNull().default("تهران، ایران"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// User authentication schemas
export const insertUserSchema = createInsertSchema(users).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const loginUserSchema = z.object({
  username: z.string().min(3, "نام کاربری باید حداقل ۳ کاراکتر باشد"),
  password: z.string().min(4, "رمز عبور باید حداقل ۴ کاراکتر باشد"),
});

// Schemas for validation
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

// Types
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
