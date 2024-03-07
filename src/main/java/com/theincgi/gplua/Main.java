package com.theincgi.gplua;

import com.theincgi.gplua.demoUI.ShaderScene;

import javafx.application.Application;
import javafx.stage.Stage;

public class Main extends Application {
	
	public static void main(String[] args) {
		launch(args);
	}
	
	ShaderScene shaderScene = new ShaderScene();
	
	@Override
	public void start(Stage primaryStage) throws Exception {
		primaryStage.setScene(shaderScene.scene);
		primaryStage.show();
	}
	
}
