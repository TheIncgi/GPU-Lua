package com.theincgi.gplua.demoUI;

import java.util.Arrays;

import javafx.scene.Node;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.image.ImageView;
import javafx.scene.image.PixelFormat;
import javafx.scene.image.WritableImage;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.GridPane;

public class ShaderScene {
	
	public Scene scene;
	GridPane grid = new GridPane();
	
	TextField file = new TextField("demo.lua");
	Label msg = new Label(":)");
	
	WritableImage img = new WritableImage(512, 512);
	ImageView imgView = new ImageView(img);
	BorderPane bp = new BorderPane();
	
	public ShaderScene() {
		scene = new Scene(bp, 512, 800);
		bp.setCenter(grid);
		bp.setBottom(imgView);
		clearImg();
		
		int r = 0;
		grid.addRow(r++, label("File: "), file);
		grid.addRow(r++, msg);
		grid.addRow(r++, label("Render:"));
		grid.addRow(r++, imgView);
	}

	private Node label(String string) {
		return new Label(string);
	}
	
	public void clearImg() {
		var w = img.getPixelWriter();
		var data = new int[512*512];
		Arrays.fill(data, 0xFF000000);
		w.setPixels(0, 0, 512, 512, PixelFormat.getIntArgbInstance(), data, 0, 512);
	}
	
	public void setImg(int[] data) {
		var w = img.getPixelWriter();
		w.setPixels(0, 0, 512, 512, PixelFormat.getIntArgbInstance(), data, 0, 512);
	}
	
}
