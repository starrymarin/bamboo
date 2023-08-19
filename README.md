所见即所得的富文本编辑器框架（开发中）

为了某些功能的实现，需要使用自定义Flutter SDK，所以flutter sdk被以submodule的方式添加到项目中，clone本项目后，进入flutter/bin，执行./flutter doctor，初始化自定义sdk，之后将IDE的flutter sdk路径修改为此flutter sdk路径