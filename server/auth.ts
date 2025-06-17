import passport from "passport";
import { Strategy as LocalStrategy } from "passport-local";
import type { Express } from "express";
import session from "express-session";
import { scrypt, randomBytes, timingSafeEqual } from "crypto";
import { promisify } from "util";
import { storage } from "./storage.js";
import { User, loginUserSchema } from "@shared/schema";
import connectPg from "connect-pg-simple";

declare global {
  namespace Express {
    interface User {
      id: number;
      username: string;
      role: string;
    }
  }
}

const scryptAsync = promisify(scrypt);

async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString("hex");
  const buf = (await scryptAsync(password, salt, 64)) as Buffer;
  return `${buf.toString("hex")}.${salt}`;
}

async function comparePasswords(supplied: string, stored: string): Promise<boolean> {
  const [hashed, salt] = stored.split(".");
  const hashedBuf = Buffer.from(hashed, "hex");
  const suppliedBuf = (await scryptAsync(supplied, salt, 64)) as Buffer;
  return timingSafeEqual(hashedBuf, suppliedBuf);
}

// Track failed login attempts
const loginAttempts = new Map<string, { count: number; lastAttempt: number }>();
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_TIME = 15 * 60 * 1000; // 15 minutes

function checkLoginAttempts(identifier: string): boolean {
  const attempts = loginAttempts.get(identifier);
  if (!attempts) return true;
  
  const now = Date.now();
  if (now - attempts.lastAttempt > LOCKOUT_TIME) {
    loginAttempts.delete(identifier);
    return true;
  }
  
  return attempts.count < MAX_LOGIN_ATTEMPTS;
}

function recordFailedLogin(identifier: string): void {
  const attempts = loginAttempts.get(identifier) || { count: 0, lastAttempt: 0 };
  attempts.count += 1;
  attempts.lastAttempt = Date.now();
  loginAttempts.set(identifier, attempts);
}

function clearLoginAttempts(identifier: string): void {
  loginAttempts.delete(identifier);
}

export function setupAuth(app: Express) {
  const PostgresSessionStore = connectPg(session);
  
  const sessionSettings: session.SessionOptions = {
    secret: process.env.SESSION_SECRET || "fallback-secret-change-in-production",
    resave: false,
    saveUninitialized: false,
    store: new PostgresSessionStore({
      conString: process.env.DATABASE_URL,
      createTableIfMissing: true,
      tableName: "sessions"
    }),
    cookie: {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      maxAge: 8 * 60 * 60 * 1000, // 8 hours
      sameSite: "strict"
    },
  };

  app.set("trust proxy", 1);
  app.use(session(sessionSettings));
  app.use(passport.initialize());
  app.use(passport.session());

  passport.use(
    new LocalStrategy(async (username, password, done) => {
      try {
        const user = await storage.getUserByUsername(username);
        if (!user || !user.isActive || !(await comparePasswords(password, user.password))) {
          return done(null, false, { message: "نام کاربری یا رمز عبور اشتباه است" });
        }
        return done(null, user);
      } catch (error) {
        return done(error);
      }
    })
  );

  passport.serializeUser((user, done) => done(null, user.id));
  
  passport.deserializeUser(async (id: number, done) => {
    try {
      const user = await storage.getUser(id);
      done(null, user);
    } catch (error) {
      done(error);
    }
  });

  // Register endpoint
  app.post("/api/register", async (req, res, next) => {
    try {
      const validatedData = loginUserSchema.parse(req.body);
      
      const existingUser = await storage.getUserByUsername(validatedData.username);
      if (existingUser) {
        return res.status(400).json({ message: "این نام کاربری قبلاً استفاده شده است" });
      }

      const hashedPassword = await hashPassword(validatedData.password);
      const user = await storage.createUser({
        username: validatedData.username,
        password: hashedPassword,
        role: "admin",
        isActive: true,
      });

      req.login(user, (err) => {
        if (err) return next(err);
        res.status(201).json({ 
          id: user.id, 
          username: user.username, 
          role: user.role 
        });
      });
    } catch (error: any) {
      res.status(400).json({ message: error.message || "خطا در ثبت نام" });
    }
  });

  // Login endpoint with rate limiting
  app.post("/api/login", (req, res, next) => {
    const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
    const { username } = req.body;
    
    // Check login attempts for both IP and username
    if (!checkLoginAttempts(clientIP) || (username && !checkLoginAttempts(username))) {
      return res.status(429).json({ 
        message: "تعداد تلاش‌های ورود بیش از حد مجاز. لطفاً ۱۵ دقیقه صبر کنید." 
      });
    }
    
    passport.authenticate("local", (err: any, user: User, info: any) => {
      if (err) return next(err);
      
      if (!user) {
        // Record failed login attempts
        recordFailedLogin(clientIP);
        if (username) recordFailedLogin(username);
        
        return res.status(401).json({ 
          message: info?.message || "نام کاربری یا رمز عبور اشتباه است" 
        });
      }
      
      // Clear login attempts on successful login
      clearLoginAttempts(clientIP);
      clearLoginAttempts(username);
      
      req.login(user, (err) => {
        if (err) return next(err);
        res.json({ 
          id: user.id, 
          username: user.username, 
          role: user.role 
        });
      });
    })(req, res, next);
  });

  // Logout endpoint
  app.post("/api/logout", (req, res, next) => {
    req.logout((err) => {
      if (err) return next(err);
      res.json({ message: "با موفقیت خارج شدید" });
    });
  });

  // Get current user
  app.get("/api/user", (req, res) => {
    if (!req.isAuthenticated() || !req.user) {
      return res.status(401).json({ message: "وارد نشده‌اید" });
    }
    res.json({ 
      id: req.user.id, 
      username: req.user.username, 
      role: req.user.role 
    });
  });
}

// Middleware to check authentication
export function requireAuth(req: any, res: any, next: any) {
  if (!req.isAuthenticated() || !req.user) {
    return res.status(401).json({ message: "برای دسترسی به این بخش باید وارد شوید" });
  }
  next();
}

// Middleware to check admin role
export function requireAdmin(req: any, res: any, next: any) {
  if (!req.isAuthenticated() || !req.user || req.user.role !== "admin") {
    return res.status(403).json({ message: "دسترسی محدود - فقط مدیران" });
  }
  next();
}