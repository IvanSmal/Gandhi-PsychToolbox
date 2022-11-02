function insToTxtbox(app, str)
    txtstr=sprintf('%s\n%s\n',str, string(get(app.InformationTextArea,'Value')));
    set(app.InformationTextArea,'Value',txtstr);
end