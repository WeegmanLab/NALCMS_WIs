library(dplyr)

# Carregar raster
r <- terra::rast("./output/nalcms_updated.tif")

# Ler legenda
legend_df <- read.csv("raster_legend.csv")

# Criar vetor de cores hex
rgb_to_hex <- function(r, g, b) sprintf("#%02X%02X%02X", r, g, b)
colors_vec <- mapply(rgb_to_hex, legend_df$r, legend_df$g, legend_df$b)

# Assumindo raster com valores inteiros correspondendo a legend_df$value
# Cria fator para colorir categorias
r_fact <- terra::as.factor(r)

# Definir levels para legenda
levels(r_fact) <- data.frame(ID = legend_df$value, label = legend_df$name)

# Plot com cores customizadas
png("landcover_map.png", width = 1200, height = 800, res = 150)  # ajuste tamanho e resolução
par(mar = c(5, 5, 4, 10))  # margem direita maior
terra::plot(r_fact, col = colors_vec, legend = TRUE, main = "Land Cover Map")
dev.off()