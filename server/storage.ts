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
import { eq, and } from "drizzle-orm";

// Interface for storage operations
export interface IStorage {
  // User operations for username/password auth
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  
  // Brand settings operations
  getBrandSettings(): Promise<BrandSettings | undefined>;
  updateBrandSettings(data: Partial<InsertBrandSettings>): Promise<BrandSettings>;
  
  // T-shirt image operations
  getActiveTshirtImages(): Promise<TshirtImage[]>;
  getAllTshirtImages(): Promise<TshirtImage[]>;
  createTshirtImage(data: InsertTshirtImage): Promise<TshirtImage>;
  updateTshirtImageDetails(id: number, data: { title?: string; description?: string; size?: string; price?: string }): Promise<TshirtImage>;
  deleteTshirtImage(id: number): Promise<void>;
  reorderTshirtImages(imageIds: number[]): Promise<void>;
  
  // Social link operations
  getActiveSocialLinks(): Promise<SocialLink[]>;
  updateSocialLinks(data: InsertSocialLink[]): Promise<SocialLink[]>;
  
  // Copyright settings operations
  getCopyrightSettings(): Promise<CopyrightSettings | undefined>;
  updateCopyrightSettings(data: InsertCopyrightSettings): Promise<CopyrightSettings>;
  
  // About content operations
  getAboutContent(): Promise<AboutContent | undefined>;
  updateAboutContent(data: InsertAboutContent): Promise<AboutContent>;
}

export class DatabaseStorage implements IStorage {
  // User operations for username/password auth
  async getUser(id: number): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.id, id));
    return user;
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.username, username));
    return user;
  }

  async createUser(userData: InsertUser): Promise<User> {
    const [user] = await db
      .insert(users)
      .values(userData)
      .returning();
    return user;
  }

  // Brand settings operations
  async getBrandSettings(): Promise<BrandSettings | undefined> {
    const [settings] = await db.select().from(brandSettings).limit(1);
    if (!settings) {
      // Create default settings if none exist
      const [newSettings] = await db
        .insert(brandSettings)
        .values({
          name: "تک پوش خاص",
          slogan: "یک از یک",
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
        .set({ ...data, updatedAt: new Date() })
        .where(eq(brandSettings.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db
        .insert(brandSettings)
        .values(data as InsertBrandSettings)
        .returning();
      return created;
    }
  }

  // T-shirt image operations
  async getActiveTshirtImages(): Promise<TshirtImage[]> {
    return await db
      .select()
      .from(tshirtImages)
      .where(eq(tshirtImages.isActive, true))
      .orderBy(tshirtImages.order);
  }

  async getAllTshirtImages(): Promise<TshirtImage[]> {
    return await db
      .select()
      .from(tshirtImages)
      .orderBy(tshirtImages.order);
  }

  async createTshirtImage(data: InsertTshirtImage): Promise<TshirtImage> {
    const [image] = await db
      .insert(tshirtImages)
      .values(data)
      .returning();
    return image;
  }

  async updateTshirtImageDetails(id: number, data: { title?: string; description?: string; size?: string; price?: string }): Promise<TshirtImage> {
    const [updatedImage] = await db
      .update(tshirtImages)
      .set({
        ...data,
        updatedAt: new Date(),
      })
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
        .set({ order: i + 1 })
        .where(eq(tshirtImages.id, imageIds[i]));
    }
  }

  // Social link operations
  async getActiveSocialLinks(): Promise<SocialLink[]> {
    return await db
      .select()
      .from(socialLinks)
      .where(eq(socialLinks.isActive, true));
  }

  async updateSocialLinks(data: InsertSocialLink[]): Promise<SocialLink[]> {
    // Delete all existing social links
    await db.delete(socialLinks);
    
    // Insert new ones
    if (data.length > 0) {
      return await db.insert(socialLinks).values(data).returning();
    }
    return [];
  }

  // Copyright settings operations
  async getCopyrightSettings(): Promise<CopyrightSettings | undefined> {
    const [settings] = await db.select().from(copyrightSettings).limit(1);
    if (!settings) {
      // Create default settings if none exist
      const [newSettings] = await db
        .insert(copyrightSettings)
        .values({
          text: "© ۱۴۰۳ تک پوش خاص. تمامی حقوق محفوظ است.",
        })
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
        .set({ ...data, updatedAt: new Date() })
        .where(eq(copyrightSettings.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db
        .insert(copyrightSettings)
        .values(data)
        .returning();
      return created;
    }
  }

  async getAboutContent(): Promise<AboutContent | undefined> {
    const [content] = await db.select().from(aboutContent).limit(1);
    return content;
  }

  async updateAboutContent(data: InsertAboutContent): Promise<AboutContent> {
    const existing = await this.getAboutContent();
    if (existing) {
      const [updated] = await db
        .update(aboutContent)
        .set({ ...data, updatedAt: new Date() })
        .where(eq(aboutContent.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db
        .insert(aboutContent)
        .values(data)
        .returning();
      return created;
    }
  }
}

export const storage = new DatabaseStorage();