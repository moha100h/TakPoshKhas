import express from "express";
import type { Express } from "express";
import { createServer } from "http";
import type { Server } from "http";
import { storage } from "./storage.js";
import { setupAuth, requireAuth, requireAdmin } from "./auth.js";
import multer from "multer";
import sharp from "sharp";
import path from "path";
import fs from "fs/promises";
import { 
  insertBrandSettingsSchema, 
  insertTshirtImageSchema, 
  insertSocialLinkSchema, 
  insertCopyrightSettingsSchema,
  insertAboutContentSchema
} from "@shared/schema";
import { z } from "zod";

// Configure multer for image uploads
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(null, false);
    }
  }
});

// Ensure uploads directory exists
const ensureUploadsDir = async () => {
  const uploadsDir = path.join(process.cwd(), 'dist', 'public', 'uploads');
  try {
    await fs.access(uploadsDir);
  } catch {
    await fs.mkdir(uploadsDir, { recursive: true });
  }
  return uploadsDir;
};

export async function registerRoutes(app: Express): Promise<Server> {
  // Health check endpoint for monitoring
  app.get('/api/health', (req, res) => {
    res.status(200).json({ 
      status: 'OK', 
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    });
  });

  // Auth middleware
  setupAuth(app);

  // Serve static uploads
  app.use('/uploads', express.static(path.join(process.cwd(), 'dist', 'public', 'uploads')));

  // Public API routes - no authentication required
  
  // Get brand settings
  app.get('/api/brand-settings', async (req, res) => {
    try {
      const settings = await storage.getBrandSettings();
      res.json(settings);
    } catch (error) {
      console.error("Error fetching brand settings:", error);
      res.status(500).json({ message: "Failed to fetch brand settings" });
    }
  });

  // Get active t-shirt images
  app.get('/api/tshirt-images', async (req, res) => {
    try {
      const images = await storage.getActiveTshirtImages();
      res.json(images);
    } catch (error) {
      console.error("Error fetching t-shirt images:", error);
      res.status(500).json({ message: "Failed to fetch t-shirt images" });
    }
  });

  // Get active social links
  app.get('/api/social-links', async (req, res) => {
    try {
      const links = await storage.getActiveSocialLinks();
      res.json(links);
    } catch (error) {
      console.error("Error fetching social links:", error);
      res.status(500).json({ message: "Failed to fetch social links" });
    }
  });

  // Get copyright settings
  app.get('/api/copyright-settings', async (req, res) => {
    try {
      const settings = await storage.getCopyrightSettings();
      res.json(settings);
    } catch (error) {
      console.error("Error fetching copyright settings:", error);
      res.status(500).json({ message: "Failed to fetch copyright settings" });
    }
  });

  // Protected admin routes
  
  // Update brand settings
  app.put('/api/admin/brand-settings', requireAdmin, async (req, res) => {
    try {
      const validatedData = insertBrandSettingsSchema.parse(req.body);
      const settings = await storage.updateBrandSettings(validatedData);
      res.json(settings);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ message: "Invalid data", errors: error.errors });
      } else {
        console.error("Error updating brand settings:", error);
        res.status(500).json({ message: "Failed to update brand settings" });
      }
    }
  });

  // Upload logo
  app.post('/api/admin/upload-logo', requireAdmin, upload.single('logo'), async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: "No file uploaded" });
      }

      const uploadsDir = await ensureUploadsDir();
      const filename = `logo-${Date.now()}.webp`;
      const filepath = path.join(uploadsDir, filename);

      // Process and save image
      await sharp(req.file.buffer)
        .resize(200, 200, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 0 } })
        .webp({ quality: 90 })
        .toFile(filepath);

      const logoUrl = `/uploads/${filename}`;
      const settings = await storage.updateBrandSettings({ logoUrl });
      res.json({ logoUrl, settings });
    } catch (error) {
      console.error("Error uploading logo:", error);
      res.status(500).json({ message: "Failed to upload logo" });
    }
  });

  // Upload single t-shirt image with metadata
  app.post('/api/admin/upload-image', requireAdmin, upload.single('image'), async (req, res) => {
    try {
      const file = req.file as Express.Multer.File;
      if (!file) {
        return res.status(400).json({ message: "No file uploaded" });
      }

      const { title, description, size, price } = req.body;
      const uploadsDir = await ensureUploadsDir();
      
      const filename = `tshirt-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.jpg`;
      const filepath = path.join(uploadsDir, filename);

      // Preserve original quality with minimal compression
      await sharp(file.buffer)
        .resize(2000, null, { 
          fit: 'inside',
          withoutEnlargement: true 
        })
        .jpeg({ quality: 98, progressive: true, mozjpeg: true })
        .toFile(filepath);

      const imageUrl = `/uploads/${filename}`;
      const image = await storage.createTshirtImage({
        imageUrl,
        title: title || "تی‌شرت جدید",
        description: description || "",
        size: size || "",
        price: price || "",
        alt: title || "تی‌شرت منحصر به فرد",
        order: 0,
        isActive: true
      });

      res.json(image);
    } catch (error) {
      console.error("Error uploading image:", error);
      res.status(500).json({ message: "Failed to upload image" });
    }
  });

  // Upload multiple t-shirt images
  app.post('/api/admin/upload-images', requireAdmin, upload.array('images', 20), async (req, res) => {
    try {
      const files = req.files as Express.Multer.File[];
      if (!files || files.length === 0) {
        return res.status(400).json({ message: "No files uploaded" });
      }

      const uploadsDir = await ensureUploadsDir();
      const uploadedImages = [];

      for (const file of files) {
        const filename = `tshirt-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.jpg`;
        const filepath = path.join(uploadsDir, filename);

        // Preserve original quality with minimal compression
        await sharp(file.buffer)
          .resize(2000, null, { 
            fit: 'inside',
            withoutEnlargement: true 
          })
          .jpeg({ quality: 98, progressive: true, mozjpeg: true })
          .toFile(filepath);

        const imageUrl = `/uploads/${filename}`;
        const image = await storage.createTshirtImage({
          imageUrl,
          title: `تی‌شرت ${uploadedImages.length + 1}`,
          description: "",
          size: "",
          price: "",
          alt: "تی‌شرت منحصر به فرد",
          order: uploadedImages.length,
          isActive: true
        });

        uploadedImages.push(image);
      }

      res.json(uploadedImages);
    } catch (error) {
      console.error("Error uploading t-shirt images:", error);
      res.status(500).json({ message: "Failed to upload images" });
    }
  });

  // Get all t-shirt images for admin
  app.get('/api/admin/tshirt-images', requireAdmin, async (req, res) => {
    try {
      const images = await storage.getAllTshirtImages();
      res.json(images);
    } catch (error) {
      console.error("Error fetching admin t-shirt images:", error);
      res.status(500).json({ message: "Failed to fetch images" });
    }
  });

  // Update t-shirt image details
  app.put('/api/admin/tshirt-images/:id', requireAdmin, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      if (isNaN(id)) {
        return res.status(400).json({ message: "Invalid image ID" });
      }

      const { title, description, size, price } = req.body;
      const updatedImage = await storage.updateTshirtImageDetails(id, {
        title,
        description,
        size,
        price,
      });

      res.json(updatedImage);
    } catch (error) {
      console.error("Error updating t-shirt image details:", error);
      res.status(500).json({ message: "Failed to update image details" });
    }
  });

  // Delete t-shirt image
  app.delete('/api/admin/tshirt-images/:id', requireAdmin, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      if (isNaN(id)) {
        return res.status(400).json({ message: "Invalid image ID" });
      }

      await storage.deleteTshirtImage(id);
      res.json({ message: "Image deleted successfully" });
    } catch (error) {
      console.error("Error deleting t-shirt image:", error);
      res.status(500).json({ message: "Failed to delete image" });
    }
  });

  // Update t-shirt images order
  app.put('/api/admin/tshirt-images/reorder', requireAdmin, async (req, res) => {
    try {
      const { imageIds } = req.body;
      if (!Array.isArray(imageIds)) {
        return res.status(400).json({ message: "Invalid image IDs" });
      }

      await storage.reorderTshirtImages(imageIds);
      res.json({ message: "Images reordered successfully" });
    } catch (error) {
      console.error("Error reordering t-shirt images:", error);
      res.status(500).json({ message: "Failed to reorder images" });
    }
  });

  // Update social links
  app.put('/api/admin/social-links', requireAdmin, async (req, res) => {
    try {
      const links = req.body;
      if (!Array.isArray(links)) {
        return res.status(400).json({ message: "Invalid social links data" });
      }

      const validatedLinks = links.map(link => insertSocialLinkSchema.parse(link));
      const updatedLinks = await storage.updateSocialLinks(validatedLinks);
      res.json(updatedLinks);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ message: "Invalid data", errors: error.errors });
      } else {
        console.error("Error updating social links:", error);
        res.status(500).json({ message: "Failed to update social links" });
      }
    }
  });

  // Update copyright settings
  app.put('/api/admin/copyright-settings', requireAdmin, async (req, res) => {
    try {
      const validatedData = insertCopyrightSettingsSchema.parse(req.body);
      const settings = await storage.updateCopyrightSettings(validatedData);
      res.json(settings);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ message: "Invalid data", errors: error.errors });
      } else {
        console.error("Error updating copyright settings:", error);
        res.status(500).json({ message: "Failed to update copyright settings" });
      }
    }
  });

  // About content routes
  app.get("/api/about-content", async (req, res) => {
    try {
      const content = await storage.getAboutContent();
      res.json(content);
    } catch (error) {
      res.status(500).json({ message: "خطا در دریافت محتوای درباره ما" });
    }
  });

  app.put("/api/admin/about-content", requireAuth, requireAdmin, async (req, res) => {
    try {
      const validatedData = insertAboutContentSchema.parse(req.body);
      const content = await storage.updateAboutContent(validatedData);
      res.json(content);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ message: "Invalid data", errors: error.errors });
      } else {
        console.error("Error updating about content:", error);
        res.status(500).json({ message: "خطا در بروزرسانی محتوای درباره ما" });
      }
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}
