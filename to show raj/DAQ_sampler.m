r= rateControl(10000);

reset(r)
for i=1:10000  
	DAQdata(i,1) = r.TotalElapsedTime;
    DAQdata(i,2) = randi(20);
	waitfor(r);
end