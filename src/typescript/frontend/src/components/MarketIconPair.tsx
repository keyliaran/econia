import Image, { type ImageProps } from "next/image";

interface ImageWithFallbackProps extends ImageProps {
  fallback?: string;
  alt: string;
  src: string;
  // [key: string]: any; // allow any other props
}

const ImageWithFallback: React.FC<ImageWithFallbackProps> = ({
  fallback = "/tokenImages/default.png",
  alt,
  src,
  ...props
}) => {
  return <Image alt={alt} src={src ?? fallback} {...props} />;
};

// copy paste from statsbar, think about making a unified component later
const DEFAULT_TOKEN_ICON = "/tokenImages/default.png";
type MarketIconPairProps = {
  baseAssetIcon?: string;
  quoteAssetIcon?: string;
  size?: number;
};
export const MarketIconPair = ({
  baseAssetIcon = DEFAULT_TOKEN_ICON,
  quoteAssetIcon = DEFAULT_TOKEN_ICON,
  size = 28,
}: MarketIconPairProps) => {
  return (
    <div className="md:w-15 relative flex" style={{ width: (size * 12) / 7 }}>
      {/* height width props required */}
      <ImageWithFallback
        src={baseAssetIcon}
        alt="market-icon-pair"
        width={size}
        height={size}
        className="z-20 aspect-square"
      ></ImageWithFallback>
      <ImageWithFallback
        src={quoteAssetIcon}
        alt="market-icon-pair"
        width={size}
        height={size}
        className="absolute z-10 aspect-square translate-x-1/2"
      ></ImageWithFallback>
    </div>
  );
};
