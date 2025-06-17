import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { TshirtImage } from "@shared/schema";
import { X, ZoomIn, Star, ShoppingBag } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

interface ProductDetailModalProps {
  product: TshirtImage;
  isOpen: boolean;
  onClose: () => void;
}

function ProductDetailModal({ product, isOpen, onClose }: ProductDetailModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4 bg-black/60 backdrop-blur-lg">
      <div className="relative w-full max-w-4xl max-h-[95vh] overflow-auto bg-[var(--pure-white)] rounded-2xl sm:rounded-3xl shadow-2xl border border-[var(--medium-gray)]">
        
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-3 left-3 sm:top-6 sm:left-6 z-10 p-2 sm:p-3 bg-black/20 backdrop-blur-sm rounded-full hover:bg-black/40 transition-colors"
        >
          <X className="w-4 h-4 sm:w-6 sm:h-6 text-white" />
        </button>
        
        {/* Mobile-First Layout */}
        <div className="flex flex-col">
          
          {/* Product Image Section */}
          <div className="relative bg-[var(--light-gray)] flex items-center justify-center min-h-[250px] sm:min-h-[350px] md:min-h-[400px]">
            <img
              src={product.imageUrl}
              alt={product.title || product.alt}
              className="w-full h-full object-contain p-4 sm:p-6 md:p-8"
              style={{ maxHeight: '60vh' }}
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[var(--primary-red)]/5 to-transparent pointer-events-none" />
            
            {/* Quality Badge */}
            <div className="absolute top-3 right-3 sm:top-4 sm:right-4">
              <div className="flex items-center space-x-reverse space-x-2 bg-[var(--pure-white)]/90 backdrop-blur-sm px-2 sm:px-3 py-1 sm:py-2 rounded-full border border-[var(--medium-gray)]">
                <Star className="w-3 h-3 sm:w-4 sm:h-4 text-[var(--primary-red)] fill-current" />
                <span className="text-xs sm:text-sm font-medium text-[var(--text-black)]">کیفیت پریمیوم</span>
              </div>
            </div>
          </div>
          
          {/* Product Details Section - Below Image */}
          <div className="p-4 sm:p-6 md:p-8 space-y-4 sm:space-y-6 bg-[var(--ice-white)]">
            
            {/* Header */}
            <div className="space-y-3 sm:space-y-4">
              <h3 className="text-xl sm:text-2xl md:text-3xl font-bold red-text leading-tight">
                {product.title || product.alt}
              </h3>
              <Badge className="bg-[var(--primary-red)]/20 text-[var(--primary-red)] border-[var(--primary-red)]/30 red-border px-3 sm:px-4 py-1 sm:py-2 text-sm font-medium">
                تک پوش خاص
              </Badge>
            </div>
            
            {/* Size and Price Row */}
            <div className="flex flex-col sm:flex-row gap-4 sm:gap-6">
              {/* Size Info */}
              {product.size && (
                <div className="space-y-2">
                  <span className="text-[var(--text-gray)] text-sm font-medium">سایز موجود:</span>
                  <div className="px-3 sm:px-4 py-2 bg-[var(--light-gray)] text-[var(--text-black)] font-semibold rounded-xl border border-[var(--medium-gray)] text-center w-fit">
                    {product.size}
                  </div>
                </div>
              )}

              {/* Price Display */}
              {product.price && (
                <div className="space-y-2">
                  <span className="text-[var(--text-gray)] text-sm font-medium">قیمت:</span>
                  <div className="flex items-center space-x-reverse space-x-2">
                    <span className="text-xl sm:text-2xl font-bold red-text">
                      {product.price}
                    </span>
                    <span className="text-[var(--text-gray)] text-sm">تومان</span>
                  </div>
                </div>
              )}
            </div>
            
            {/* Separator */}
            <div className="red-separator"></div>
            
            {/* Description Section */}
            <div className="space-y-3">
              <span className="text-[var(--text-gray)] text-sm font-medium">توضیحات محصول:</span>
              <p className="text-[var(--text-black)] leading-relaxed text-sm sm:text-base">
                {product.description || "این طراحی منحصر به فرد از مجموعه تک پوش خاص، ترکیبی از هنر مدرن و کیفیت بالا است که سبک منحصر به فرد شما را نمایان می‌کند."}
              </p>
            </div>

            {/* Action Button */}
            <div className="pt-6 border-t border-[var(--medium-gray)]">
              <Button className="w-full modern-btn text-lg py-4 rounded-2xl">
                <ShoppingBag className="w-5 h-5 ml-3" />
                مشاهده بیشتر
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function ModernTShirtGallery() {
  const [selectedProduct, setSelectedProduct] = useState<TshirtImage | null>(null);

  const { data: tshirtImages, isLoading, error } = useQuery<TshirtImage[]>({
    queryKey: ["/api/tshirt-images"],
    retry: false,
  });

  const openProductDetail = (product: TshirtImage) => {
    setSelectedProduct(product);
  };

  const closeProductDetail = () => {
    setSelectedProduct(null);
  };

  if (isLoading) {
    return (
      <div className="responsive-container py-4 md:py-8">
        <div className="responsive-grid-4 gap-3 sm:gap-4 md:gap-6 lg:gap-8">
          {[...Array(8)].map((_, i) => (
            <div
              key={i}
              className="modern-card animate-pulse h-64 sm:h-80 md:h-96"
            >
              <div className="bg-[var(--light-gray)] h-44 sm:h-52 md:h-60 rounded-t-2xl" />
              <div className="p-3 sm:p-4 md:p-6 space-y-2 sm:space-y-3">
                <div className="h-3 sm:h-4 bg-[var(--light-gray)] rounded" />
                <div className="h-2 sm:h-3 bg-[var(--light-gray)] rounded w-2/3" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-20">
        <div className="max-w-md mx-auto space-y-6">
          <div className="w-24 h-24 mx-auto bg-[var(--light-red)] rounded-full flex items-center justify-center">
            <span className="text-3xl">⚠️</span>
          </div>
          <div>
            <h3 className="text-xl font-semibold text-[var(--text-black)] mb-2">
              خطا در بارگذاری
            </h3>
            <p className="text-[var(--text-gray)]">
              لطفاً صفحه را مجدداً بارگذاری کنید
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (!tshirtImages?.length) {
    return (
      <div className="text-center py-20">
        <div className="max-w-md mx-auto space-y-6">
          <div className="w-24 h-24 mx-auto bg-[var(--light-gray)] rounded-full flex items-center justify-center">
            <ShoppingBag className="w-10 h-10 text-[var(--text-gray)]" />
          </div>
          <h3 className="text-xl font-semibold text-[var(--text-black)]">
            هنوز محصولی اضافه نشده
          </h3>
          <p className="text-[var(--text-gray)]">
            به زودی مجموعه زیبای ما را خواهید دید
          </p>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* Optimized Mobile-First Gallery Grid */}
      <div className="responsive-container py-4 md:py-8">
        <div className="responsive-grid-4 gap-3 sm:gap-4 md:gap-6 lg:gap-8">
          {tshirtImages.map((tshirt, index) => (
            <div
              key={tshirt.id}
              className="modern-card group cursor-pointer overflow-hidden hover:scale-105 transition-all duration-500"
              onClick={() => openProductDetail(tshirt)}
              style={{ 
                animationDelay: `${index * 100}ms` 
              }}
            >
              
              {/* Mobile-Optimized Image Container */}
              <div className="relative overflow-hidden rounded-t-2xl bg-[var(--light-gray)] h-44 sm:h-52 md:h-60 lg:h-64">
                <img
                  src={tshirt.imageUrl}
                  alt={tshirt.title || tshirt.alt}
                  className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                  loading={index < 4 ? "eager" : "lazy"}
                />
                
                {/* Hover Overlay */}
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                
                {/* Mobile-Friendly Zoom Icon */}
                <div className="absolute top-2 right-2 md:top-4 md:right-4 opacity-0 group-hover:opacity-100 transition-all duration-300 transform translate-y-2 group-hover:translate-y-0">
                  <div className="p-1.5 md:p-2 bg-[var(--pure-white)]/90 backdrop-blur-sm rounded-full border border-[var(--medium-gray)]">
                    <ZoomIn className="w-3 h-3 md:w-4 md:h-4 text-[var(--primary-red)]" />
                  </div>
                </div>

                {/* Mobile-Optimized Premium Badge */}
                <div className="absolute bottom-2 left-2 md:bottom-4 md:left-4 opacity-0 group-hover:opacity-100 transition-all duration-300 transform translate-y-2 group-hover:translate-y-0">
                  <Badge className="bg-[var(--primary-red)]/90 text-white border-0 backdrop-blur-sm">
                    پریمیوم
                  </Badge>
                </div>
              </div>
            
            {/* Content */}
            <div className="p-6 space-y-4">
              
              {/* Title */}
              <h3 className="font-bold text-lg text-[var(--text-black)] line-clamp-2 group-hover:text-[var(--primary-red)] transition-colors">
                {tshirt.title || tshirt.alt}
              </h3>
              
              {/* Details Row */}
              <div className="flex items-center justify-between">
                {tshirt.size && (
                  <span className="text-sm text-[var(--text-gray)] bg-[var(--light-gray)] px-3 py-1 rounded-lg">
                    {tshirt.size}
                  </span>
                )}
                
                {tshirt.price && (
                  <span className="font-bold red-text">
                    {tshirt.price} ت
                  </span>
                )}
              </div>
              
              {/* Description Preview */}
              {tshirt.description && (
                <p className="text-sm text-[var(--text-gray)] line-clamp-2 leading-relaxed">
                  {tshirt.description}
                </p>
              )}
              
              {/* Action Hint */}
              <div className="pt-2 border-t border-[var(--medium-gray)]">
                <span className="text-xs text-[var(--text-gray)] group-hover:text-[var(--primary-red)] transition-colors">
                  برای مشاهده جزئیات کلیک کنید
                </span>
              </div>
            </div>
          </div>
          ))}
        </div>

        {/* Product Detail Modal */}
        {selectedProduct && (
          <ProductDetailModal
            product={selectedProduct}
            isOpen={!!selectedProduct}
            onClose={closeProductDetail}
          />
        )}
      </div>
    </>
  );
}