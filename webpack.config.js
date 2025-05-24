const path = require("path");
const Dotenv = require("dotenv-webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");

module.exports = {
  entry: "./src/frontend/index.js",
  output: {
    filename: "bundle.js",
    path: path.resolve(__dirname, "dist"),
  },
  target: "web",
  devtool: "source-map",
  mode: process.env.NODE_ENV == "production" ? "production" : "development",
  plugins: [
    new HtmlWebpackPlugin({
      template: path.resolve(__dirname, "src", "frontend", "index.html"),
      inject: true,
    }),
    new Dotenv(),
  ],
  devServer: {
    hot: true,
    watchFiles: {
      paths: [path.resolve(__dirname, "src", "frontend")],
      options: {
        ignored: /^.*/,
      },
    },
  },
};
